const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

function plugin(id, respond = () => ({ status: 200, data: {} }), initial = {}) {
  const storage = new Map(Object.entries(initial));
  const settings = new Map();
  const requests = [];
  const delays = [];
  const logs = [];
  const writes = [];
  let source;
  const http = async (method, url, headers = {}, body) => {
    const request = { method, url, headers, body };
    requests.push(request);
    const result = await respond(request, requests);
    return {
      status: result.status ?? 200,
      headers: {},
      body: result.body ?? JSON.stringify(result.data),
    };
  };
  const api = {
    apiVersion: 1,
    registerSource(value) {
      assert.equal(source, undefined, "register exactly once");
      source = value;
    },
    storage: {
      get: (key) => storage.get(key),
      set: async (key, value) => {
        writes.push([key, value]);
        storage.set(key, value);
      },
      delete: async (key) => {
        storage.delete(key);
      },
    },
    settings: {
      get: (key) => settings.get(key) ?? source.settings?.[key]?.default,
    },
    http: {
      get: (url, headers) => http("GET", url, headers),
      post: (url, headers, body) => http("POST", url, headers, body),
      sendRequest: http,
    },
    convert: {
      md5: (value) => crypto.createHash("md5").update(value).digest(),
      hexEncode: (value) => Buffer.from(value).toString("hex"),
      encodeUtf8: (value) => Buffer.from(value, "utf8"),
      decodeUtf8: (value) => Buffer.from(value).toString("utf8"),
      encodeBase64: (value) => Buffer.from(value).toString("base64"),
      decodeBase64: (value) => Buffer.from(value, "base64"),
      hmacString: (key, value, algorithm) =>
        crypto.createHmac(algorithm, key).update(value).digest("hex"),
    },
    images: { reverseVerticalTiles: (segments) => ({ segments }) },
    delay: async (ms) => {
      delays.push(ms);
    },
    log: (message, level) => {
      logs.push({ message, level });
    },
    error: (code, message) =>
      new Error("hazuki_" + code.toLowerCase() + ": " + message),
  };
  // Deliberately expose only API v1; legacy app globals are unavailable.
  const context = vm.createContext({ Hazuki: api });
  vm.runInContext(
    fs.readFileSync(path.join(__dirname, "..", id, "main.js"), "utf8"),
    context,
  );
  return { source, storage, settings, requests, delays, logs, writes, context };
}

const picaUser = {
  name: "Pica User",
  avatar: { fileServer: "https://images.example/", path: "/avatar.jpg" },
  isPunched: false,
};
function picaResponse(request) {
  if (request.url.endsWith("/auth/sign-in"))
    return { data: { data: { token: "pica-token" } } };
  if (request.url.endsWith("/users/profile"))
    return { data: { data: { user: picaUser } } };
  return { data: { data: { comics: { docs: [], pages: 1 } } } };
}

for (const id of ["jm", "picacg", "copy_manga"]) {
  test(
    id + " registers API v1 without legacy globals or import-time I/O",
    () => {
      const app = plugin(id);
      assert.equal(app.source.id, id);
      assert.equal(app.source.apiVersion, 1);
      assert.equal(app.requests.length, 0);
      assert.equal(app.writes.length, 0);
      for (const setting of Object.values(app.source.settings)) {
        assert.ok(["input", "select", "switch", "bool"].includes(setting.type));
      }
    },
  );
}

test("Picacg signs the configured API and converts profile media to a complete URL", async () => {
  const app = plugin("picacg", picaResponse);
  app.settings.set("base_url", "https://custom.example///");
  app.settings.set("appChannel", "1");
  app.settings.set("imageQuality", "medium");
  const result = await app.source.account.login("user", "password");
  assert.equal(result.token, "pica-token");
  assert.equal(result.avatarUrl, "https://images.example/static/avatar.jpg");
  assert.equal(result.displayName, "Pica User");
  const login = app.requests[0];
  assert.equal(login.url, "https://custom.example/auth/sign-in");
  assert.equal(login.headers["app-channel"], "1");
  assert.equal(login.headers["image-quality"], "medium");
  assert.equal(login.headers.nonce.length, 32);
  const key =
    "~d}$Q7$eIni=V)9\\RK/P.RM4;9[7|@/CA}b~OW!3?EV`:<>M7pddUBL5n|0/*Cn";
  const data = (
    "auth/sign-in" +
    login.headers.time +
    login.headers.nonce +
    "POST" +
    login.headers["api-key"]
  ).toLowerCase();
  assert.equal(
    login.headers.signature,
    crypto.createHmac("sha256", key).update(data).digest("hex"),
  );
  assert.ok(!JSON.stringify(app.logs).includes("pica-token"));
});

test("Picacg tries both profile signature paths before falling back to old client headers", async () => {
  const app = plugin(
    "picacg",
    (request) =>
      request.headers["app-channel"] === "2"
        ? {
            data: {
              user: {
                ...picaUser,
                avatar: { fullUrl: "https://images.example/full.jpg" },
              },
            },
          }
        : { status: 403, data: {} },
    { token: "token" },
  );
  app.settings.set("appChannel", "1");
  const profile = await app.source.account.loadProfile();
  assert.equal(profile.avatarUrl, "https://images.example/full.jpg");
  assert.equal(app.requests.length, 3);
  assert.notEqual(
    app.requests[0].headers.signature,
    app.requests[1].headers.signature,
  );
  assert.equal(app.requests[2].headers["app-build-version"], "44");
});

test("Picacg continues profile lookup when the first signature returns a name but no avatar", async () => {
  const app = plugin(
    "picacg",
    (_, requests) => ({
      data: {
        data: {
          user:
            requests.length === 1
              ? { name: "Name only" }
              : { ...picaUser, avatar: "//images.example/avatar.jpg" },
        },
      },
    }),
    { token: "token" },
  );
  const profile = await app.source.account.loadProfile();
  assert.equal(profile.avatarUrl, "https://images.example/avatar.jpg");
  assert.equal(app.requests.length, 2);
});

test("Picacg uses a UTF-8 JWT name when the profile service fails without failing login", async () => {
  const token =
    "header." +
    Buffer.from(JSON.stringify({ name: "哔咔用户" })).toString("base64url") +
    ".signature";
  const app = plugin("picacg", (request) =>
    request.url.endsWith("/auth/sign-in")
      ? { data: { data: { token } } }
      : { status: 503, data: {} },
  );
  const profile = await app.source.account.login("user", "password");
  assert.equal(profile.token, token);
  assert.equal(profile.displayName, "哔咔用户");
  assert.equal(profile.avatarUrl, undefined);
});

test("Picacg shares a single relogin for concurrent expired requests and returns successful retries", async () => {
  let loginCount = 0;
  const app = plugin(
    "picacg",
    (request) => {
      if (request.url.endsWith("/auth/sign-in")) {
        loginCount++;
        return picaResponse(request);
      }
      if (request.url.includes("/users/profile")) return picaResponse(request);
      if (request.headers.authorization !== "pica-token")
        return { status: 401, data: {} };
      if (request.url.endsWith("/recommendation"))
        return { data: { data: { comics: [] } } };
      if (request.url.includes("/eps?"))
        return {
          data: {
            data: { eps: { docs: [{ order: 1, title: "First" }], pages: 1 } },
          },
        };
      return {
        data: { data: { comic: { title: "Recovered", pagesCount: 7 } } },
      };
    },
    { token: "expired", account: ["user", "password"] },
  );
  const details = await app.source.comic.loadInfo("comic-id");
  assert.equal(details.title, "Recovered");
  assert.equal(details.pageCount, 7);
  assert.equal(details.chapters.get("1"), "First");
  assert.equal(loginCount, 1);
});

test("Picacg check-in normalizes punch-state variants and avoids duplicate submissions", async () => {
  let submissions = 0;
  const app = plugin(
    "picacg",
    (request) => {
      if (request.url.endsWith("/users/punch-in")) {
        submissions++;
        return { data: { message: "今天已签到" } };
      }
      return {
        data: {
          isPunched: "false",
          name: "User",
          avatar: "https://images.example/avatar.jpg",
        },
      };
    },
    { token: "token" },
  );
  const results = await Promise.all([
    app.source.account.checkIn(),
    app.source.account.checkIn(),
  ]);
  assert.equal(submissions, 1);
  assert.equal(results[0].status, "alreadyCheckedIn");
  assert.equal(results[1].status, "alreadyCheckedIn");
  const punched = plugin(
    "picacg",
    () => ({ data: { data: { user: { ...picaUser, isPunched: 1 } } } }),
    { token: "token" },
  );
  assert.equal(await punched.source.account.checkInStatus(), true);
  assert.equal(
    (await punched.source.account.checkIn()).status,
    "alreadyCheckedIn",
  );
  assert.equal(
    punched.requests.some((request) => request.url.endsWith("/users/punch-in")),
    false,
  );
});

test("Picacg reports ordinary server failures without labelling them expired sessions", async () => {
  const app = plugin(
    "picacg",
    (request) =>
      request.url.endsWith("/users/profile")
        ? picaResponse(request)
        : { status: 503, data: {} },
    { token: "token" },
  );
  await assert.rejects(app.source.account.checkIn(), /Picacg HTTP 503/);
  await assert.rejects(
    app.source.search.load("test", [], 1),
    /Picacg HTTP 503/,
  );
});

test("Picacg paginates episode images and returns complete comment avatar URLs", async () => {
  const app = plugin(
    "picacg",
    (request) => {
      if (request.url.includes("/pages?")) {
        const page = Number(new URL(request.url).searchParams.get("page"));
        return {
          data: {
            data: {
              pages: {
                docs: [
                  {
                    media: {
                      fileServer: "https://images.example",
                      path: page + ".jpg",
                    },
                  },
                ],
                pages: 2,
              },
            },
          },
        };
      }
      return {
        data: {
          data: {
            comments: {
              docs: [
                {
                  _id: "comment",
                  content: "Hello",
                  _user: {
                    name: "Reader",
                    avatar: { fullUrl: "//images.example/user.jpg" },
                  },
                },
              ],
              pages: 1,
            },
          },
        },
      };
    },
    { token: "token" },
  );
  assert.deepEqual(
    Array.from((await app.source.comic.loadEp("id", "1")).images),
    [
      "https://images.example/static/1.jpg",
      "https://images.example/static/2.jpg",
    ],
  );
  assert.equal(
    (await app.source.comic.loadComments("id", null, 1, null)).comments[0]
      .avatar,
    "https://images.example/user.jpg",
  );
});

test("CopyManga form-encodes credentials, awaits device storage and normalizes login fields", async () => {
  const app = plugin("copy_manga", () => ({
    data: {
      results: {
        token: "copy-token",
        nickname: "Copy User",
        user_cover: "/user/cover/avatar.jpg",
      },
    },
  }));
  const result = await app.source.account.login("user+name&x=1", "password");
  assert.equal(
    result.avatarUrl,
    "https://s3.mangafuna.xyz/user/cover/avatar.jpg",
  );
  assert.equal(result.displayName, "Copy User");
  const request = app.requests[0];
  const body = new URLSearchParams(request.body);
  assert.equal(body.get("username"), "user+name&x=1");
  assert.ok(
    Buffer.from(body.get("password").trim(), "base64")
      .toString("utf8")
      .startsWith("password-"),
  );
  assert.ok(request.body.includes("\n&salt="));
  for (const key of ["_device", "_deviceinfo", "_pseudoid"])
    assert.equal(request.headers[key.slice(1)], app.storage.get(key));
});

test("both plugins preserve an existing token when login is rejected or malformed", async () => {
  for (const id of ["picacg", "copy_manga"]) {
    for (const response of [
      { status: 401, data: {} },
      { status: 200, data: { results: {}, data: {} } },
      { status: 200, body: "invalid json" },
    ]) {
      const app = plugin(id, () => response, { token: "previous-token" });
      await assert.rejects(app.source.account.login("user", "password"));
      assert.equal(app.storage.get("token"), "previous-token");
    }
  }
});

test("CopyManga refreshes avatars through a bounded relogin and retains cached data on failure", async () => {
  const app = plugin(
    "copy_manga",
    () => ({
      data: {
        results: { token: "new-token", avatar: "//images.example/avatar.jpg" },
      },
    }),
    { token: "token", account: ["user", "password"] },
  );
  const [first, second] = await Promise.all([
    app.source.account.loadProfile(),
    app.source.account.loadProfile(),
  ]);
  assert.equal(first.avatarUrl, "https://images.example/avatar.jpg");
  assert.equal(second.avatarUrl, first.avatarUrl);
  assert.equal(
    (await app.source.account.loadProfile()).avatarUrl,
    first.avatarUrl,
  );
  assert.equal(app.requests.length, 1);
  const failed = plugin("copy_manga", () => ({ status: 503, data: {} }), {
    token: "old-token",
    avatar_url: "https://images.example/cached.jpg",
    account: ["user", "password"],
  });
  assert.equal(
    (await failed.source.account.loadProfile()).avatarUrl,
    "https://images.example/cached.jpg",
  );
  assert.equal(failed.storage.get("token"), "old-token");
});

test("CopyManga concurrent requests share persisted device IDs", async () => {
  const app = plugin("copy_manga", () => ({
    data: { results: { list: [], total: 0 } },
  }));
  await Promise.all([
    app.source.search.load("first", [], 1),
    app.source.search.load("second", [], 1),
  ]);
  for (const key of ["_device", "_deviceinfo", "_pseudoid"]) {
    assert.equal(app.writes.filter(([written]) => written === key).length, 1);
    assert.equal(
      app.requests[0].headers[key.slice(1)],
      app.requests[1].headers[key.slice(1)],
    );
  }
});

test("CopyManga retrieves a missing avatar even after a successful login", async () => {
  const app = plugin(
    "copy_manga",
    (_, requests) => ({
      data: {
        results:
          requests.length === 1
            ? { token: "token" }
            : { token: "token", avatar: "user/cover/found.jpg" },
      },
    }),
    { account: ["user", "password"] },
  );
  await app.source.account.login("user", "password");
  assert.equal(
    (await app.source.account.loadProfile()).avatarUrl,
    "https://s3.mangafuna.xyz/user/cover/found.jpg",
  );
  assert.equal(app.requests.length, 2);
});

test("CopyManga retries HTTP 210 in the plugin, changes device IDs and preserves image order and quality", async () => {
  const app = plugin("copy_manga", (_, requests) =>
    requests.length === 1
      ? { status: 210, data: { message: "Expected available in 2 seconds" } }
      : {
          data: {
            results: {
              chapter: {
                contents: [
                  { url: "https://images.example/second/c800x.jpg" },
                  { url: "https://images.example/first/c800x.jpg" },
                ],
                words: [1, 0],
              },
            },
          },
        },
  );
  app.settings.set("image_quality", "1200");
  const result = await app.source.comic.loadEp("comic", "chapter");
  assert.deepEqual(Array.from(result.images), [
    "https://images.example/first/c1200x.webp",
    "https://images.example/second/c1200x.webp",
  ]);
  assert.deepEqual(app.delays, [2000]);
  assert.notEqual(
    app.requests[0].headers.device,
    app.requests[1].headers.device,
  );
  assert.equal(app.source.presentation.recreateOnStatus, undefined);
});

test("CopyManga bounds read retries and never retries comment submissions", async () => {
  const app = plugin("copy_manga", () => ({
    status: 210,
    data: { message: "Expected available in 0 seconds" },
  }));
  await assert.rejects(app.source.search.load("test", [], 1), /HTTP 210/);
  assert.equal(
    app.requests.filter((request) =>
      request.url.includes("/api/v3/search/comic"),
    ).length,
    5,
  );
  assert.equal(app.delays.length, 4);
  const comments = plugin("copy_manga", () => ({ status: 210, data: {} }), {
    token: "token",
  });
  await assert.rejects(
    comments.source.comic.sendComment("comic", "uuid", "Hello", null),
    /HTTP 210/,
  );
  assert.equal(comments.requests.length, 1);
  assert.equal(comments.delays.length, 0);
});

test("CopyManga refreshes its default API host after an HTTP 210 recovery", async () => {
  let reads = 0;
  const app = plugin("copy_manga", (request) => {
    if (request.url.includes("/system/network2"))
      return { data: { results: { api: [["api.recovered.example"]] } } };
    if (++reads === 1)
      return {
        status: 210,
        data: { message: "Expected available in 0 seconds" },
      };
    return { data: { results: { list: [], total: 0 } } };
  });
  await app.source.search.load("keyword", [], 1);
  assert.equal(reads, 2);
  assert.ok(
    app.requests.at(-1).url.startsWith("https://api.recovered.example/"),
  );
});

test("CopyManga uses 30-item pages and normalizes comment IDs and avatars", async () => {
  const app = plugin("copy_manga", (request) =>
    request.url.includes("/comments?")
      ? {
          data: {
            results: {
              list: [
                {
                  id: 9,
                  user_name: "Reader",
                  user_avatar: "user/cover/avatar.jpg",
                  comment: "Hi",
                },
              ],
              total: 20,
            },
          },
        }
      : {
          data: {
            results: {
              list: [
                {
                  path_word: "comic",
                  name: "Comic",
                  cover: "https://images.example/cover.jpg",
                },
              ],
              total: 60,
            },
          },
        },
  );
  const page = await app.source.search.load("keyword", ["-"], 2);
  assert.equal(page.maxPage, 2);
  assert.equal(new URL(app.requests[0].url).searchParams.get("offset"), "30");
  assert.equal(new URL(app.requests[0].url).searchParams.get("q_type"), "");
  const comments = await app.source.comic.loadComments(
    "comic",
    "uuid",
    1,
    null,
  );
  assert.equal(comments.maxPage, 1);
  assert.equal(comments.comments[0].id, "9");
  assert.equal(
    comments.comments[0].avatar,
    "https://s3.mangafuna.xyz/user/cover/avatar.jpg",
  );
});

test("CopyManga flattens grouped chapters into the declared ID-to-title contract", async () => {
  const app = plugin("copy_manga", (request) => {
    if (request.url.endsWith("/query"))
      return { data: { results: { collect: null } } };
    if (request.url.includes("/chapters?")) {
      const url = new URL(request.url);
      const offset = Number(url.searchParams.get("offset"));
      const group = url.pathname.includes("/group/main/") ? "main" : "extra";
      return {
        data: {
          results: {
            list: [{ uuid: group + offset, name: group + offset }],
            total: group === "main" ? 101 : 1,
          },
        },
      };
    }
    return {
      data: {
        results: {
          comic: { name: "Comic", uuid: "uuid", status: { display: "连载中" } },
          groups: {
            main: { path_word: "main" },
            extra: { path_word: "extra" },
          },
        },
      },
    };
  });
  const result = await app.source.comic.loadInfo("comic");
  assert.deepEqual(
    Array.from(result.chapters.entries(), (pair) => Array.from(pair)),
    [
      ["main0", "main0"],
      ["main100", "main100"],
      ["extra0", "extra0"],
    ],
  );
  assert.equal(result.subId, "uuid");
});

test("CopyManga discovers endpoints through API v1 and preserves a user-selected host", async () => {
  const app = plugin("copy_manga", (request) =>
    request.url.endsWith("/search")
      ? { body: 'const countApi = "/api/custom/search"' }
      : request.url.includes("/system/network2")
        ? { data: { results: { api: [["api.discovered.example"]] } } }
        : { data: { results: { list: [], total: 0 } } },
  );
  app.settings.set("base_url", "api.user.example");
  app.settings.set("search_api", "webAPI");
  await app.source.init();
  await app.source.search.load("test", [], 1);
  assert.ok(
    app.requests
      .at(-1)
      .url.startsWith("https://api.user.example/api/custom/search"),
  );
  app.settings.delete("base_url");
  await app.source.search.load("test", [], 1);
  assert.ok(
    app.requests.at(-1).url.startsWith("https://api.discovered.example/"),
  );
});


test("JM normalizes HTTPS URLs inside the plugin without altering unrelated URLs", () => {
  const app = plugin("jm");
  const normalize = (url) => vm.runInContext(`jmNormalizeUrl(${JSON.stringify(url)})`, app.context);
  assert.equal(normalize("https://www.cdntwice.org:45176/a?q=1#frag"), "https://www.cdntwice.org/a?q=1#frag");
  assert.equal(normalize("https://user:pass@cdnsha.jmapiproxyxxx.vip:45176/a"), "https://user:pass@cdnsha.jmapiproxyxxx.vip/a");
  assert.equal(normalize("https://example.com:45176/a"), "https://example.com:45176/a");
  assert.equal(normalize("http://www.cdntwice.org:45176/a"), "http://www.cdntwice.org:45176/a");
  const image = app.source.comic.onImageLoad("https://cdnhth.jmapiproxyxxx.vip:45176/1.jpg", "7", "250000");
  assert.equal(image.url, "https://cdnhth.jmapiproxyxxx.vip/1.jpg");
  assert.equal(image.segments, 10);
  const later = app.source.comic.onImageLoad("https://cdnhth.jmapiproxyxxx.vip:45176/1.jpg", "7", "500000");
  const hash = crypto.createHash("md5").update("5000001").digest("hex");
  assert.equal(later.segments, (hash.charCodeAt(hash.length - 1) % 8) * 2 + 2);
});
