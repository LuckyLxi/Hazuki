/*
# Source attribution

Adapted from [venera-configs/copy_manga.js](https://github.com/venera-app/venera-configs/blob/e28e134074308c0006408272639a53b9af9ce9da/copy_manga.js), commit `e28e134074308c0006408272639a53b9af9ce9da`.

The upstream repository did not contain a root license file at this commit. No additional license grant is asserted for the upstream code. Upstream attribution is retained. Hazuki API v1 integration uses the project license.
*/
/// <reference path="../hazuki-source.d.ts" />
// @ts-check

const copyDefaultApiHost = "api.copy2000.online";
const copyDefaultRegion = "0";
const copyDefaultImageQuality = "1500";
/** @type {Record<string, string>} */
const copyCategories = {
  全部: "",
  愛情: "aiqing",
  歡樂向: "huanlexiang",
  冒險: "maoxian",
  奇幻: "qihuan",
  百合: "baihe",
  校园: "xiaoyuan",
  科幻: "kehuan",
  東方: "dongfang",
  耽美: "danmei",
  生活: "shenghuo",
  格鬥: "gedou",
  轻小说: "qingxiaoshuo",
  悬疑: "xuanyi",
  其他: "qita",
  神鬼: "shengui",
  职场: "zhichang",
  TL: "teenslove",
  萌系: "mengxi",
  治愈: "zhiyu",
  長條: "changtiao",
  四格: "sige",
  节操: "jiecao",
  舰娘: "jianniang",
  竞技: "jingji",
  搞笑: "gaoxiao",
  伪娘: "weiniang",
  热血: "rexue",
  励志: "lizhi",
  性转换: "xingzhuanhuan",
  彩色: "COLOR",
  後宮: "hougong",
  美食: "meishi",
  侦探: "zhentan",
  AA: "aa",
  音乐舞蹈: "yinyuewudao",
  魔幻: "mohuan",
  战争: "zhanzheng",
  历史: "lishi",
  异世界: "yishijie",
  惊悚: "jingsong",
  机战: "jizhan",
  都市: "dushi",
  穿越: "chuanyue",
  恐怖: "kongbu",
  C100: "comiket100",
  重生: "chongsheng",
  C99: "comiket99",
  C101: "comiket101",
  C97: "comiket97",
  C96: "comiket96",
  生存: "shengcun",
  宅系: "zhaixi",
  武侠: "wuxia",
  C98: "C98",
  C95: "comiket95",
  FATE: "fate",
  转生: "zhuansheng",
  無修正: "Uncensored",
  仙侠: "xianxia",
  LoveLive: "loveLive",
};
/** @type {Record<string, string>} */
let copyAuthors = {};
let copySearchApi = "/api/kb/web/searchb/comics";
/** @type {Record<string, string>} */
let copyDeviceData = {};
/** @type {Promise<void> | null} */
let copyDevicesPending = null;
/** @type {Promise<SourceProfile> | null} */
let copyProfilePending = null;
let copyLastProfileRefresh = 0;

function copyBaseUrl() {
  const host = String(
    Hazuki.settings.get("base_url") || copyDefaultApiHost,
  ).replace(/\/+$/, "");
  return /^https?:\/\//.test(host) ? host : "https://" + host;
}

/** @param {number} min @param {number} max */
function copyRandomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

/** @param {string} key @param {() => string} generate */
async function copyDeviceValue(key, generate) {
  const value = Hazuki.storage.get(key);
  const result = typeof value === "string" && value ? value : generate();
  if (result !== value) await Hazuki.storage.set(key, result);
  return result;
}

async function copyEnsureDevices() {
  if (copyDevicesPending) return copyDevicesPending;
  copyDevicesPending = copyInitializeDevices();
  try {
    await copyDevicesPending;
  } finally {
    copyDevicesPending = null;
  }
}

async function copyInitializeDevices() {
  for (const [key, generate] of Object.entries({
    _deviceinfo: () =>
      copyRandomInt(1000000, 9999999) + "V-" + copyRandomInt(1000, 9999),
    _device: () => {
      const letter = () => String.fromCharCode(65 + copyRandomInt(0, 25));
      const digit = () => String(copyRandomInt(0, 9));
      return (
        letter() +
        letter() +
        digit() +
        letter() +
        "." +
        Array.from({ length: 6 }, digit).join("") +
        "." +
        Array.from({ length: 3 }, digit).join("")
      );
    },
    _pseudoid: () => {
      const chars =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
      return Array.from(
        { length: 16 },
        () => chars[copyRandomInt(0, chars.length - 1)],
      ).join("");
    },
  }))
    copyDeviceData[key] = await copyDeviceValue(key, generate);
}

/** @returns {Record<string, string>} */
function copyHeaders() {
  const now = new Date();
  const time = String(Math.floor(now.getTime() / 1000));
  const token = String(Hazuki.storage.get("token") || "");
  return {
    "User-Agent": "COPY/3.0.6",
    source: "copyApp",
    deviceinfo: copyDeviceData._deviceinfo,
    dt:
      now.getFullYear() +
      "." +
      String(now.getMonth() + 1).padStart(2, "0") +
      "." +
      String(now.getDate()).padStart(2, "0"),
    platform: "3",
    referer: "com.copymanga.app-3.0.6",
    version: "3.0.6",
    device: copyDeviceData._device,
    pseudoid: copyDeviceData._pseudoid,
    Accept: "application/json",
    region: String(Hazuki.settings.get("region") || copyDefaultRegion),
    authorization: token ? "Token " + token : "Token",
    umstring: "b4c89ca4104ea9a97750314d791520ac",
    "x-auth-timestamp": time,
    "x-auth-signature": Hazuki.convert.hmacString(
      Hazuki.convert.decodeBase64(
        "M2FmMDg1OTAzMTEwMzJlZmUwNjYwNTUwYTA1NjNhNTM=",
      ),
      Hazuki.convert.encodeUtf8(time),
      "sha256",
    ),
  };
}

/** @param {Record<string, unknown>} values */
function copyForm(values) {
  return Object.entries(values)
    .map(
      ([key, value]) =>
        encodeURIComponent(key) + "=" + encodeURIComponent(String(value)),
    )
    .join("&");
}

/** @param {string} path @param {'GET' | 'POST'} method @param {unknown} body @param {boolean} recover @returns {Promise<any>} */
async function copyRequest(
  path,
  method = "GET",
  body = undefined,
  recover = true,
) {
  await copyEnsureDevices();
  // Site rate limits and stale device IDs are handled here, without rebuilding the host runtime.
  for (let attempt = 0; attempt < (recover ? 5 : 1); attempt++) {
    const headers = copyHeaders();
    if (method === "POST")
      headers["Content-Type"] =
        "application/x-www-form-urlencoded;charset=utf-8";
    const response = await Hazuki.http.sendRequest(
      method,
      copyBaseUrl() + path,
      headers,
      body,
    );
    if (response.status === 401)
      throw Hazuki.error("AUTH_EXPIRED", "CopyManga session expired");
    if (response.status === 210 && recover && attempt < 4) {
      let wait = 40000;
      try {
        const message = String(JSON.parse(response.body).message || "");
        const seconds = message.match(
          /Expected available in\s*(\d+)\s*seconds/i,
        );
        if (seconds) wait = Math.min(Number(seconds[1]) * 1000, 90000);
      } catch (_) {}
      for (const key of ["_deviceinfo", "_device", "_pseudoid"])
        await Hazuki.storage.delete(key);
      await copyEnsureDevices();
      if (attempt === 0) {
        try {
          await copyRefreshAppApi();
        } catch (error) {
          Hazuki.log(
            "CopyManga endpoint refresh failed: " + String(error),
            "warn",
          );
        }
      }
      Hazuki.log("CopyManga rate limited; retry " + (attempt + 1), "warn");
      await Hazuki.delay(wait);
      continue;
    }
    if (response.status !== 200)
      throw new Error("CopyManga HTTP " + response.status);
    return JSON.parse(response.body);
  }
  throw new Error("CopyManga retry limit reached");
}

async function copyRequestId() {
  if (String(Hazuki.settings.get("region") || copyDefaultRegion) === "0")
    return "";
  try {
    await copyEnsureDevices();
    const response = await Hazuki.http.get(
      "https://marketing.aiacgn.com/api/v2/adopr/query3/?format=json&ident=200100001",
      copyHeaders(),
    );
    return response.status === 200
      ? String(JSON.parse(response.body).results?.request_id || "")
      : "";
  } catch (_) {
    return "";
  }
}

/** @param {unknown} avatar @returns {string | undefined} */
function copyAvatarUrl(avatar) {
  if (typeof avatar !== "string" || !avatar.trim()) return undefined;
  const value = avatar.trim();
  if (/^https?:\/\//.test(value)) return value;
  if (value.startsWith("//")) return "https:" + value;
  return "https://s3.mangafuna.xyz/" + value.replace(/^\/+/, "");
}

/** @param {any} result @returns {SourceProfile} */
function copyProfile(result) {
  const avatarUrl = copyAvatarUrl(
    result.avatar ??
      result.user_cover ??
      result.cover ??
      result.avatar_url ??
      result.user_avatar,
  );
  const displayName = result.nickname || result.username;
  return {
    ...(typeof result.token === "string" ? { token: result.token } : {}),
    ...(avatarUrl ? { avatarUrl } : {}),
    ...(displayName ? { displayName: String(displayName) } : {}),
  };
}

/** @param {string} account @param {string} password @returns {Promise<SourceProfile>} */
async function copyLogin(account, password) {
  const salt = copyRandomInt(1000, 9999);
  const encoded = Hazuki.convert.encodeBase64(
    Hazuki.convert.encodeUtf8(password + "-" + salt),
  );
  // Preserve the upstream newline, but form-encode credentials and Base64 characters.
  const result = (
    await copyRequest(
      "/api/v3/login",
      "POST",
      copyForm({ username: account, password: encoded }) +
        "\n&salt=" +
        salt +
        "&authorization=Token+",
      false,
    )
  ).results;
  if (typeof result?.token !== "string" || !result.token.trim())
    throw new Error("Missing login token");
  // No storage write occurs until the response is validated, preserving an existing token on failure.
  await Hazuki.storage.set("token", result.token);
  const profile = copyProfile(result);
  if (profile.displayName)
    await Hazuki.storage.set("display_name", profile.displayName);
  if (profile.avatarUrl)
    await Hazuki.storage.set("avatar_url", profile.avatarUrl);
  copyLastProfileRefresh = Date.now();
  return profile;
}

/** @returns {Promise<SourceProfile>} */
async function copyLoadProfile() {
  if (!Hazuki.storage.get("token")) return {};
  if (copyProfilePending) return copyProfilePending;
  const cached = {
    displayName: String(Hazuki.storage.get("display_name") || ""),
    avatarUrl: String(Hazuki.storage.get("avatar_url") || ""),
  };
  if (
    cached.avatarUrl &&
    copyLastProfileRefresh &&
    Date.now() - copyLastProfileRefresh < 120000
  )
    return cached;
  const account = Hazuki.storage.get("account");
  if (!Array.isArray(account) || account.length < 2) return cached;
  copyProfilePending = copyLogin(String(account[0]), String(account[1]));
  try {
    return await copyProfilePending;
  } catch (error) {
    Hazuki.log("CopyManga avatar refresh failed: " + String(error), "warn");
    return cached;
  } finally {
    copyProfilePending = null;
  }
}

async function copyRefreshSearchApi() {
  const response = await Hazuki.http.get("https://www.copy20.com/search");
  if (response.status === 200) {
    const match = response.body.match(/const countApi = "([^"]+)"/);
    if (match && match[1].startsWith("/")) copySearchApi = match[1];
  }
}

async function copyRefreshAppApi() {
  await copyEnsureDevices();
  const response = await Hazuki.http.get(
    "https://api.copy-manga.com/api/v3/system/network2?platform=3",
    copyHeaders(),
  );
  if (response.status === 200) {
    const host = JSON.parse(response.body).results?.api?.[0]?.[0];
    if (typeof host === "string" && host.trim()) {
      // Keep an explicit user setting; only replace the plugin's default.
      if (source.settings) source.settings.base_url.default = host;
    }
  }
}

/** @param {any} item @returns {SourceComic} */
function copyComic(item) {
  const comic = item.comic || item;
  return {
    id: String(comic.path_word),
    title: String(comic.name || ""),
    cover: String(comic.cover || ""),
    tags: (comic.theme || []).map((/** @type {any} */ tag) => String(tag.name)),
  };
}

/** @param {any} result @param {number} pageSize @returns {ComicPage} */
function copyPage(result, pageSize = 30) {
  return {
    comics: (result.list || []).map(copyComic),
    maxPage: Math.max(1, Math.ceil(Number(result.total || 0) / pageSize)),
  };
}

/** @param {string} id @param {any} groups @returns {Promise<Map<string, string>>} */
async function copyChapters(id, groups) {
  const entries = await Promise.all(
    Object.values(groups || {}).map(async (group) => {
      /** @type {[string, string][]} */
      const chapters = [];
      const requestId = await copyRequestId();
      for (let offset = 0; ; offset += 100) {
        const result = (
          await copyRequest(
            "/api/v3/comic/" +
              id +
              "/group/" +
              group.path_word +
              "/chapters?limit=100&offset=" +
              offset +
              "&in_mainland=true&request_id=" +
              requestId,
          )
        ).results;
        chapters.push(
          ...result.list.map((/** @type {any} */ ep) => [
            String(ep.uuid),
            String(ep.name),
          ]),
        );
        if (offset + 100 >= Number(result.total || 0)) break;
      }
      return chapters;
    }),
  );
  return new Map(entries.flat());
}

/** @param {any} comment @param {string | null} replyTo @param {string} fallbackId @returns {SourceComment} */
function copyComment(comment, replyTo, fallbackId = "") {
  return {
    id: String(comment.id ?? fallbackId),
    userName: replyTo
      ? String(comment.user_name) + "  👉  " + String(comment.parent_user_name)
      : String(comment.user_name || ""),
    avatar: copyAvatarUrl(comment.user_avatar),
    content: String(comment.comment || ""),
    time: String(comment.create_at || ""),
    replyCount: Number(comment.count || 0),
  };
}

/** @type {HazukiSourceDefinition} */
const source = {
  id: "copy_manga",
  name: "CopyManga",
  version: "1.0.2",
  apiVersion: 1,
  init: async () => {
    await copyEnsureDevices();
    for (const refresh of [copyRefreshSearchApi, copyRefreshAppApi]) {
      try {
        await refresh();
      } catch (error) {
        Hazuki.log(String(error), "warn");
      }
    }
  },
  account: {
    login: copyLogin,
    loadProfile: copyLoadProfile,
    logout: async () => {
      for (const key of ["token", "avatar_url", "display_name"])
        await Hazuki.storage.delete(key);
      copyLastProfileRefresh = 0;
    },
  },
  explore: [
    {
      title: "拷贝漫画",
      type: "singlePageWithMultiPart",
      load: async () => {
        const data = (await copyRequest("/api/v3/h5/homeIndex")).results;
        return {
          推荐: (data.recComics.list || []).map(copyComic),
          热门: (data.hotComics || []).map(copyComic),
          最新: (data.newComics || []).map(copyComic),
          完结: (data.finishComics.list || []).map(copyComic),
          今日排行: (data.rankDayComics.list || []).map(copyComic),
          本周排行: (data.rankWeekComics.list || []).map(copyComic),
          本月排行: (data.rankMonthComics.list || []).map(copyComic),
        };
      },
    },
  ],
  category: {
    title: "拷贝漫画",
    parts: [
      {
        name: "拷贝漫画",
        type: "fixed",
        categories: ["排行"],
        categoryParams: ["ranking"],
        itemType: "category",
      },
      {
        name: "主题",
        type: "fixed",
        categories: Object.keys(copyCategories),
        categoryParams: Object.values(copyCategories),
        itemType: "category",
      },
    ],
  },
  categoryComics: {
    load: async (category, param, options, page) => {
      const offset = (page - 1) * 30;
      const url =
        category === "排行" || param === "ranking"
          ? "/api/v3/ranks?limit=30&offset=" +
            offset +
            "&_update=true&type=1&audience_type=" +
            (options[0] || "male") +
            "&date_type=" +
            (options[1] || "day")
          : "/api/v3/comics?limit=30&offset=" +
            offset +
            "&ordering=" +
            (options[1] || "*datetime_updated").replace("*", "-") +
            "&theme=" +
            (copyCategories[category] ?? param ?? "") +
            "&top=" +
            (options[0] || "");
      return copyPage((await copyRequest(url)).results);
    },
    optionList: [
      {
        options: [
          "-全部",
          "japan-日漫",
          "korea-韩漫",
          "west-美漫",
          "finish-已完结",
        ],
        showWhen: Object.keys(copyCategories),
      },
      {
        options: [
          "*datetime_updated-时间倒序",
          "datetime_updated-时间正序",
          "*popular-热度倒序",
          "popular-热度正序",
        ],
        showWhen: Object.keys(copyCategories),
      },
      {
        options: ["male-男频", "female-女频"],
        showWhen: ["排行"],
      },
      {
        options: [
          "day-上升最快",
          "week-最近7天",
          "month-最近30天",
          "total-總榜單",
        ],
        showWhen: ["排行"],
      },
    ],
  },
  search: {
    load: async (keyword, options, page) => {
      const author = keyword.startsWith("作者:") ? keyword.slice(3).trim() : "";
      const offset = (page - 1) * 30;
      const url =
        author && copyAuthors[author]
          ? "/api/v3/comics?limit=30&offset=" +
            offset +
            "&ordering=-datetime_updated&author=" +
            encodeURIComponent(copyAuthors[author])
          : (Hazuki.settings.get("search_api") === "webAPI"
              ? copySearchApi
              : "/api/v3/search/comic") +
            "?limit=30&offset=" +
            offset +
            "&q=" +
            encodeURIComponent(keyword) +
            "&q_type=" +
            (options[0] === "-" ? "" : options[0] || "");
      return copyPage((await copyRequest(url)).results);
    },
  },
  favorites: {
    addOrDelFavorite: async (id, folder, adding) => {
      const requestId = await copyRequestId();
      const result = (
        await copyRequest(
          "/api/v3/comic2/" +
            id +
            "?in_mainland=true&request_id=" +
            requestId +
            "&platform=3",
        )
      ).results;
      await copyRequest(
        "/api/v3/member/collect/comic",
        "POST",
        copyForm({
          comic_id: result.comic.uuid,
          is_collect: adding ? 1 : 0,
          authorization: "Token " + String(Hazuki.storage.get("token") || ""),
        }),
        false,
      );
    },
    loadComics: async (page) =>
      copyPage(
        (
          await copyRequest(
            "/api/v3/member/collect/comics?limit=30&offset=" +
              (page - 1) * 30 +
              "&free_type=1&ordering=" +
              String(
                Hazuki.settings.get("favorites_ordering") ||
                  "-datetime_updated",
              ),
          )
        ).results,
      ),
  },
  comic: {
    loadInfo: async (id) => {
      const requestId = await copyRequestId();
      const [info, favorite] = await Promise.all([
        copyRequest(
          "/api/v3/comic2/" +
            id +
            "?in_mainland=true&request_id=" +
            requestId +
            "&platform=3",
        ),
        copyRequest("/api/v3/comic2/" + id + "/query"),
      ]);
      const comic = info.results.comic;
      if (Object.keys(copyAuthors).length > 100) copyAuthors = {};
      for (const author of comic.author || [])
        copyAuthors[author.name] = author.path_word;
      return {
        id,
        title: String(comic.name || ""),
        cover: String(comic.cover || ""),
        description: String(comic.brief || ""),
        tags: {
          作者: (comic.author || []).map((/** @type {any} */ author) =>
            String(author.name),
          ),
          更新: [String(comic.datetime_updated || "")],
          标签: (comic.theme || []).map((/** @type {any} */ tag) =>
            String(tag.name),
          ),
          状态: [String(comic.status?.display || "")],
        },
        infoFields: [
          {
            label: { zh: "作者", en: "Author" },
            values: (comic.author || []).map((/** @type {any} */ author) =>
              String(author.name),
            ),
            action: "search",
          },
          {
            label: { zh: "标签", en: "Tags" },
            values: (comic.theme || []).map((/** @type {any} */ tag) =>
              String(tag.name),
            ),
            action: "search",
          },
          {
            label: { zh: "状态", en: "Status" },
            values: String(comic.status?.display || ""),
          },
        ],
        headerStats: [{ text: String(comic.status?.display || "") }],
        updateTime: String(comic.datetime_updated || ""),
        chapters: await copyChapters(id, info.results.groups),
        isFavorite: favorite.results.collect != null,
        subId: String(comic.uuid),
      };
    },
    loadEp: async (id, ep) => {
      const requestId = await copyRequestId();
      const chapter = (
        await copyRequest(
          "/api/v3/comic/" +
            id +
            "/chapter2/" +
            ep +
            "?in_mainland=true&request_id=" +
            requestId,
        )
      ).results.chapter;
      const quality = String(
        Hazuki.settings.get("image_quality") || copyDefaultImageQuality,
      );
      /** @type {string[]} */
      const images = Array(chapter.contents.length).fill("");
      chapter.contents.forEach(
        (/** @type {any} */ item, /** @type {number} */ index) => {
          const order = Number(chapter.words[index]);
          if (
            !Number.isInteger(order) ||
            order < 0 ||
            order >= images.length ||
            images[order]
          )
            throw new Error("Invalid chapter image order");
          images[order] = String(item.url).replace(
            /([./])c\d+x\.[a-zA-Z]+$/,
            "$1c" + quality + "x.webp",
          );
        },
      );
      if (images.some((url) => !url))
        throw new Error("Incomplete chapter image order");
      return { images };
    },
    loadComments: async (id, subId, page, replyTo) => {
      const result = (
        await copyRequest(
          "/api/v3/comments?comic_id=" +
            subId +
            "&limit=20&offset=" +
            (page - 1) * 20 +
            (replyTo ? "&reply_id=" + replyTo + "&_update=true" : ""),
          "GET",
          undefined,
          false,
        )
      ).results;
      return {
        comments: result.list.map((/** @type {any} */ comment) =>
          copyComment(comment, replyTo),
        ),
        maxPage: Math.max(1, Math.ceil(Number(result.total || 0) / 20)),
      };
    },
    sendComment: async (id, subId, text, replyTo) => {
      await copyRequest(
        "/api/v3/member/comment",
        "POST",
        copyForm({ comic_id: subId, comment: text, reply_id: replyTo || "" }),
        false,
      );
    },
    loadChapterComments: async (id, ep, page) => {
      const result = (
        await copyRequest(
          "/api/v3/roasts?chapter_id=" +
            ep +
            "&limit=20&offset=" +
            (page - 1) * 20,
          "GET",
          undefined,
          false,
        )
      ).results;
      return {
        comments: result.list.map(
          (/** @type {any} */ comment, /** @type {number} */ index) =>
            copyComment(comment, null, ep + ":" + page + ":" + index),
        ),
        maxPage: Math.max(1, Math.ceil(Number(result.total || 0) / 20)),
      };
    },
    sendChapterComment: async (id, ep, text) => {
      await copyRequest(
        "/api/v3/member/roast",
        "POST",
        copyForm({ chapter_id: ep, roast: text }),
        false,
      );
    },
  },
  settings: {
    favorites_ordering: {
      title: "收藏排序方式",
      type: "select",
      options: [
        {
          value: "-datetime_updated",
          text: "更新时间",
        },
        {
          value: "-datetime_modifier",
          text: "收藏时间",
        },
        {
          value: "-datetime_browse",
          text: "阅读时间",
        },
      ],
      default: "-datetime_updated",
    },
    region: {
      location: "lines",
      title: "CDN线路",
      type: "select",
      options: [
        {
          value: "1",
          text: "大陆线路",
        },
        {
          value: "0",
          text: "海外线路",
        },
      ],
      default: copyDefaultRegion,
    },
    image_quality: {
      title: "图片质量",
      type: "select",
      options: [
        {
          value: "800",
          text: "低 (800)",
        },
        {
          value: "1200",
          text: "中 (1200)",
        },
        {
          value: "1500",
          text: "高 (1500)",
        },
      ],
      default: copyDefaultImageQuality,
    },
    search_api: {
      location: "lines",
      title: "搜索方式",
      type: "select",
      options: [
        {
          value: "baseAPI",
          text: "基础API",
        },
        {
          value: "webAPI",
          text: "网页端API",
        },
      ],
      default: "baseAPI",
    },
    base_url: {
      location: "lines",
      title: "API地址",
      type: "input",
      default: copyDefaultApiHost,
    },
  },
  actions: {
    clearDeviceInfo: async () => {
      for (const key of ["_deviceinfo", "_device", "_pseudoid"])
        await Hazuki.storage.delete(key);
      await copyEnsureDevices();
      await copyRefreshAppApi();
      return "设备信息已重置";
    },
  },
  translation: {
    en: {
      收藏排序方式: "Favorite order",
      更新时间: "Update time",
      收藏时间: "Added time",
      阅读时间: "Reading time",
      CDN线路: "CDN region",
      大陆线路: "Mainland China",
      海外线路: "Overseas",
      图片质量: "Image quality",
      "低 (800)": "Low (800)",
      "中 (1200)": "Medium (1200)",
      "高 (1500)": "High (1500)",
      搜索方式: "Search method",
      基础API: "App API",
      网页端API: "Web API",
      API地址: "API address",
      重置设备信息: "Reset device information",
      设备信息已重置: "Device information reset",
    },
  },
  presentation: {
    showComments: true,
    buttons: [
      {
        id: "resetDeviceInfo",
        location: "advanced",
        action: "clearDeviceInfo",
        title: {
          zh: "清除拷贝漫画设备信息",
          en: "Clear CopyManga device info",
        },
        subtitle: {
          zh: "清除伪装客户端的设备标识，下次请求会重新生成",
          en: "Clear device IDs. They regenerate on the next request.",
        },
        successMessage: {
          zh: "拷贝漫画设备信息已清除",
          en: "CopyManga device info cleared",
        },
      },
      { id: "imageQuality", location: "reading" },
      { id: "imageQuality", location: "reader" },
    ],
    legacyRanking: true,
    commentReplies: true,
    skipPeriodicRelogin: true,
    showComicStatus: true,
    searchDefaultOrder: "-",
    searchOrders: {
      "-": "全部",
      name: "名称",
      author: "作者",
      local: "汉化组",
    },
    favoriteOrders: [
      "-datetime_updated",
      "-datetime_modifier",
      "-datetime_browse",
    ],
    favoriteDefaultOrder: "-datetime_updated",
    favoriteOrderAliases: { mp: "-datetime_updated", mr: "-datetime_modifier" },
    localFavoriteOrders: {
      "-datetime_updated": "updatedNewest",
      "-datetime_modifier": "savedNewest",
      "-datetime_browse": "savedNewest",
    },
    favoriteOrderSetting: "favorites_ordering",
    imageQualitySetting: "image_quality",
    actions: [
      {
        id: "clearDeviceInfo",
        title: "重置设备信息",
        location: "plugin",
      },
    ],
    refreshCloudFavorites: true,
    imageQualityOptions: {
      800: "低",
      1200: "中",
      1500: "高",
    },
    imageQualityDefault: "1500",
  },
};
Hazuki.registerSource(source);
