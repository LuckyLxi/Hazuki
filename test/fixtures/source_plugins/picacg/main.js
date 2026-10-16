/*
# Source attribution

Adapted from [venera-configs/picacg.js](https://github.com/venera-app/venera-configs/blob/e28e134074308c0006408272639a53b9af9ce9da/picacg.js), commit `e28e134074308c0006408272639a53b9af9ce9da`.

The upstream repository did not contain a root license file at this commit. No additional license grant is asserted for the upstream code. Upstream attribution is retained. Hazuki API v1 integration uses the project license.
*/
/// <reference path="../hazuki-source.d.ts" />
// @ts-check

const picacgDefaultApiUrl = "https://picaapi.picacomic.com";
const picacgApiKey = "C69BAF41DA5ABD1FFEDC6D2FEA56B";
/** @type {Promise<SourceProfile> | null} */
let picacgReloginPending = null;
/** @type {Promise<{status: 'success' | 'alreadyCheckedIn' | 'skipped'; message?: string}> | null} */
let picacgCheckInPending = null;

function picacgBaseUrl() {
  return String(Hazuki.settings.get("base_url") || picacgDefaultApiUrl).replace(
    /\/+$/,
    "",
  );
}

/** @param {string} method @param {string} path @param {string} token @param {boolean} legacy */
function picacgHeaders(method, path, token = "", legacy = false) {
  const uuid = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = Math.floor(Math.random() * 16);
    return (c === "x" ? r : (r & 3) | 8).toString(16);
  });
  const nonce = uuid.replace(/-/g, "");
  const time = (Date.now() / 1000).toFixed(0);
  const key =
    "~d}$Q7$eIni=V)9\\RK/P.RM4;9[7|@/CA}b~OW!3?EV`:<>M7pddUBL5n|0/*Cn";
  const signature = Hazuki.convert.hmacString(
    Hazuki.convert.encodeUtf8(key),
    Hazuki.convert.encodeUtf8(
      (path + time + nonce + method.toUpperCase() + picacgApiKey).toLowerCase(),
    ),
    "sha256",
  );
  return {
    "api-key": picacgApiKey,
    accept: "application/vnd.picacomic.com.v1+json",
    "app-channel": legacy
      ? "2"
      : String(Hazuki.settings.get("appChannel") || "3"),
    authorization: token,
    time,
    nonce,
    signature,
    "app-version": legacy ? "2.2.1.2.3.3" : "2.2.1.3.3.4",
    "app-uuid": uuid,
    "image-quality": legacy
      ? "original"
      : String(Hazuki.settings.get("imageQuality") || "original"),
    "app-platform": "android",
    "app-build-version": legacy ? "44" : "45",
    "Content-Type": "application/json; charset=UTF-8",
    "user-agent": "okhttp/3.8.1",
    version: legacy ? "v1.4.1" : "v1.5.4",
  };
}

/** @param {string} method @param {string} path @param {unknown} body @param {boolean} retry @returns {Promise<any>} */
async function picacgRequest(method, path, body = undefined, retry = true) {
  let response = await Hazuki.http.sendRequest(
    method,
    picacgBaseUrl() + "/" + path,
    picacgHeaders(method, path, String(Hazuki.storage.get("token") || "")),
    body === undefined ? undefined : JSON.stringify(body),
  );
  if (response.status === 401 && retry) {
    await picacgRelogin();
    response = await Hazuki.http.sendRequest(
      method,
      picacgBaseUrl() + "/" + path,
      picacgHeaders(method, path, String(Hazuki.storage.get("token") || "")),
      body === undefined ? undefined : JSON.stringify(body),
    );
  }
  if (response.status === 401)
    throw Hazuki.error("AUTH_EXPIRED", "Picacg session expired");
  if (response.status !== 200)
    throw new Error("Picacg HTTP " + response.status);
  return JSON.parse(response.body);
}

async function picacgRelogin() {
  if (picacgReloginPending) return picacgReloginPending;
  const account = Hazuki.storage.get("account");
  if (!Array.isArray(account) || account.length < 2)
    throw Hazuki.error("AUTH_EXPIRED", "Missing stored account");
  picacgReloginPending = picacgLogin(String(account[0]), String(account[1]));
  try {
    return await picacgReloginPending;
  } finally {
    picacgReloginPending = null;
  }
}

/** @param {unknown} avatar @returns {string | undefined} */
function picacgAvatarUrl(avatar) {
  if (avatar && typeof avatar === "object") {
    const media =
      /** @type {{fullUrl?: string; fileServer?: string; path?: string}} */ (
        avatar
      );
    if (media.fullUrl) return picacgAvatarUrl(media.fullUrl);
    if (media.fileServer && media.path) {
      return picacgAvatarUrl(
        media.fileServer.replace(/\/+$/, "") +
          "/static/" +
          media.path.replace(/^\/+/, ""),
      );
    }
  }
  if (typeof avatar !== "string") return undefined;
  const url = avatar.trim();
  return /^https?:\/\//.test(url)
    ? url
    : url.startsWith("//")
      ? "https:" + url
      : undefined;
}

/** @param {string} token @returns {string | undefined} */
function picacgTokenName(token) {
  try {
    let payload = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    payload = payload.padEnd(Math.ceil(payload.length / 4) * 4, "=");
    const name = JSON.parse(
      Hazuki.convert.decodeUtf8(Hazuki.convert.decodeBase64(payload)),
    ).name;
    return typeof name === "string" && name.trim() ? name.trim() : undefined;
  } catch (_) {
    return undefined;
  }
}

/** @returns {Promise<any | null>} */
async function picacgProfileUser() {
  const token = String(Hazuki.storage.get("token") || "");
  if (!token) return null;
  let fallback = null;
  // Both signature paths and the old profile client headers were supported by the host patch.
  for (const [signaturePath, legacy] of [
    ["/users/profile", false],
    ["users/profile", false],
    ["/users/profile", true],
    ["users/profile", true],
  ]) {
    try {
      const response = await Hazuki.http.get(
        picacgBaseUrl() + "/users/profile",
        picacgHeaders("GET", String(signaturePath), token, Boolean(legacy)),
      );
      if (response.status !== 200) continue;
      const body = JSON.parse(response.body);
      const user = body.data?.user || body.data || body.user || body;
      if (user && typeof user === "object") {
        fallback ??= user;
        if (picacgAvatarUrl(user.avatar)) return user;
      }
    } catch (error) {
      Hazuki.log("Picacg profile request failed: " + String(error), "warn");
    }
  }
  return fallback;
}

/** @returns {Promise<SourceProfile>} */
async function picacgLoadProfile() {
  const token = String(Hazuki.storage.get("token") || "");
  if (!token) return {};
  const user = await picacgProfileUser();
  const displayName = user?.name || picacgTokenName(token);
  const avatarUrl = picacgAvatarUrl(user?.avatar);
  return {
    ...(displayName ? { displayName: String(displayName) } : {}),
    ...(avatarUrl ? { avatarUrl } : {}),
  };
}

/** @param {string} account @param {string} password @returns {Promise<SourceProfile>} */
async function picacgLogin(account, password) {
  const response = await Hazuki.http.post(
    picacgBaseUrl() + "/auth/sign-in",
    picacgHeaders("POST", "auth/sign-in"),
    JSON.stringify({ email: account, password }),
  );
  // Trace status only; never log the response token or overwrite global HTTP functions.
  Hazuki.log({ operation: "login", status: response.status });
  if (response.status === 401)
    throw Hazuki.error("AUTH_EXPIRED", "Picacg login rejected");
  if (response.status !== 200)
    throw new Error("Picacg login HTTP " + response.status);
  const token = JSON.parse(response.body).data?.token;
  if (typeof token !== "string" || !token.trim())
    throw new Error("Missing login token");
  await Hazuki.storage.set("token", token);
  return { token, ...(await picacgLoadProfile()) };
}

/** @param {unknown} value @returns {boolean | null} */
function picacgPunched(value) {
  if (value === true || value === 1 || value === "true") return true;
  if (value === false || value === 0 || value === "false") return false;
  return null;
}

async function picacgCheckInStatus() {
  return picacgPunched((await picacgProfileUser())?.isPunched);
}

/** @returns {Promise<{status: 'success' | 'alreadyCheckedIn' | 'skipped'; message?: string}>} */
async function picacgCheckIn() {
  if (picacgCheckInPending) return picacgCheckInPending;
  picacgCheckInPending = (async () => {
    if (!Hazuki.storage.get("token")) return { status: "skipped" };
    if (await picacgCheckInStatus()) return { status: "alreadyCheckedIn" };
    const result = await picacgRequest("POST", "users/punch-in", {});
    const message = result.message == null ? undefined : String(result.message);
    return {
      status: /already checked|已签到|今天已签/i.test(message || "")
        ? "alreadyCheckedIn"
        : "success",
      message,
    };
  })();
  try {
    return await picacgCheckInPending;
  } finally {
    picacgCheckInPending = null;
  }
}

/** @param {any} comic @returns {SourceComic} */
function picacgComic(comic) {
  return {
    id: String(comic._id),
    title: String(comic.title || ""),
    cover: picacgAvatarUrl(comic.thumb) || "",
    tags: [...(comic.tags || []), ...(comic.categories || [])],
  };
}

/** @param {any} comics @returns {ComicPage} */
function picacgPage(comics) {
  return {
    comics: (Array.isArray(comics) ? comics : comics.docs || []).map(
      picacgComic,
    ),
    maxPage: Array.isArray(comics) ? 1 : Number(comics.pages || 1),
  };
}

/** @param {any} comment @returns {SourceComment} */
function picacgComment(comment) {
  return {
    id: String(comment._id),
    userName: String(comment._user?.name || ""),
    avatar: picacgAvatarUrl(comment._user?.avatar),
    content: String(comment.content || ""),
    isLiked: Boolean(comment.isLiked),
    score: Number(comment.likesCount || 0),
    replyCount: Number(comment.commentsCount || 0),
    time: String(comment.created_at || ""),
  };
}

/** @type {HazukiSourceDefinition} */
const source = {
  id: "picacg",
  name: "Picacg",
  version: "1.0.3",
  apiVersion: 1,
  account: {
    login: picacgLogin,
    logout: () => Hazuki.storage.delete("token"),
    loadProfile: picacgLoadProfile,
    checkInStatus: picacgCheckInStatus,
    checkIn: picacgCheckIn,
  },
  explore: [
    {
      title: "Picacg Random",
      type: "multiPageComicList",
      load: async () =>
        picacgPage((await picacgRequest("GET", "comics/random")).data.comics),
    },
    {
      title: "Picacg Latest",
      type: "multiPageComicList",
      load: async (page) =>
        picacgPage(
          (await picacgRequest("GET", "comics?page=" + page + "&s=dd")).data
            .comics,
        ),
    },
    ...["H24", "D7", "D30"].map((period) => ({
      title: "Picacg " + period,
      type: /** @type {'multiPageComicList'} */ ("multiPageComicList"),
      load: async () =>
        picacgPage(
          (
            await picacgRequest(
              "GET",
              "comics/leaderboard?tt=" + period + "&ct=VC",
            )
          ).data.comics,
        ),
    })),
  ],
  category: {
    /// 标题, 同时为标识符, 不能与其他漫画源的分类页面重复
    title: "Picacg",
    parts: [
      {
        name: "主题",
        type: "fixed",
        categories: [
          "大家都在看",
          "大濕推薦",
          "那年今天",
          "官方都在看",
          "嗶咔漢化",
          "全彩",
          "長篇",
          "同人",
          "短篇",
          "圓神領域",
          "碧藍幻想",
          "CG雜圖",
          "英語 ENG",
          "生肉",
          "純愛",
          "百合花園",
          "耽美花園",
          "偽娘哲學",
          "後宮閃光",
          "扶他樂園",
          "單行本",
          "姐姐系",
          "妹妹系",
          "SM",
          "性轉換",
          "足の恋",
          "人妻",
          "NTR",
          "強暴",
          "非人類",
          "艦隊收藏",
          "Love Live",
          "SAO 刀劍神域",
          "Fate",
          "東方",
          "WEBTOON",
          "禁書目錄",
          "歐美",
          "Cosplay",
          "重口地帶",
        ],
        itemType: "category",
      },
    ],
  },
  categoryComics: {
    load: async (category, param, options, page) =>
      picacgPage(
        (
          await picacgRequest(
            "GET",
            "comics?page=" +
              page +
              "&" +
              (param || "c") +
              "=" +
              encodeURIComponent(category) +
              "&s=" +
              (options[0] || "dd"),
          )
        ).data.comics,
      ),
    optionList: [
      {
        options: [
          "dd-New to old",
          "da-Old to new",
          "ld-Most likes",
          "vd-Most nominated",
        ],
      },
    ],
    ranking: {
      options: ["H24-Day", "D7-Week", "D30-Month"],
      load: async (option) =>
        picacgPage(
          (
            await picacgRequest(
              "GET",
              "comics/leaderboard?tt=" + option + "&ct=VC",
            )
          ).data.comics,
        ),
    },
  },
  search: {
    load: async (keyword, options, page) =>
      picacgPage(
        (
          await picacgRequest("POST", "comics/advanced-search?page=" + page, {
            keyword,
            sort: options[0] || "dd",
          })
        ).data.comics,
      ),
  },
  favorites: {
    addOrDelFavorite: async (comicId) => {
      await picacgRequest("POST", "comics/" + comicId + "/favourite", {});
    },
    loadComics: async (page) =>
      picacgPage(
        (
          await picacgRequest(
            "GET",
            "users/favourite?page=" +
              page +
              "&s=" +
              String(Hazuki.settings.get("favoriteSort") || "dd"),
          )
        ).data.comics,
      ),
  },
  comic: {
    loadInfo: async (id) => {
      const [infoResponse, relatedResponse] = await Promise.all([
        picacgRequest("GET", "comics/" + id),
        picacgRequest("GET", "comics/" + id + "/recommendation"),
      ]);
      const episodes = [];
      for (let page = 1; ; page++) {
        const data = (
          await picacgRequest("GET", "comics/" + id + "/eps?page=" + page)
        ).data.eps;
        episodes.push(...data.docs);
        if (page >= Number(data.pages || 1)) break;
      }
      episodes.sort((a, b) => a.order - b.order);
      const info = infoResponse.data.comic;
      const updated = new Date(info.updated_at);
      return {
        id,
        title: String(info.title || ""),
        cover: picacgAvatarUrl(info.thumb) || "",
        description: String(info.description || ""),
        tags: {
          ...(info.author ? { Author: [info.author] } : {}),
          ...(info.chineseTeam ? { "Chinese Team": [info.chineseTeam] } : {}),
          Categories: info.categories || [],
          Tags: info.tags || [],
        },
        infoFields: [
          {
            label: { zh: "作者", en: "Author" },
            values: info.author ? [String(info.author)] : [],
            action: "search",
          },
          {
            label: { zh: "分类", en: "Categories" },
            values: info.categories || [],
            action: "search",
          },
          {
            label: { zh: "标签", en: "Tags" },
            values: info.tags || [],
            action: "search",
          },
          {
            label: { zh: "上传者", en: "Uploader" },
            values: String(info._creator?.name || ""),
            action: "search",
          },
          {
            label: { zh: "汉化组", en: "Chinese team" },
            values: info.chineseTeam ? [String(info.chineseTeam)] : [],
            action: "search",
          },
          {
            label: { zh: "状态", en: "Status" },
            values:
              typeof info.finished === "boolean"
                ? info.finished
                  ? "已完结"
                  : "连载中"
                : "",
          },
        ],
        chapters: new Map(
          episodes.map((ep, index) => [String(index + 1), String(ep.title)]),
        ),
        isFavorite: Boolean(info.isFavourite),
        isLiked: Boolean(info.isLiked),
        recommend: (relatedResponse.data.comics || []).map(picacgComic),
        headerStats: [
          {
            text:
              info.likesCount == null
                ? ""
                : {
                    zh: `${info.likesCount}点赞`,
                    en: `${info.likesCount} likes`,
                  },
            action: "like",
          },
          {
            text:
              info.pagesCount == null
                ? ""
                : {
                    zh: `${info.pagesCount}页`,
                    en: `${info.pagesCount} pages`,
                  },
          },
        ],
        likesCount: info.likesCount,
        uploader: String(info._creator?.name || ""),
        pageCount: info.pagesCount,
        updateTime: Number.isNaN(updated.getTime())
          ? ""
          : updated.getFullYear() +
            "-" +
            (updated.getMonth() + 1) +
            "-" +
            updated.getDate(),
      };
    },
    loadEp: async (id, ep) => {
      const images = [];
      for (let page = 1; ; page++) {
        const data = (
          await picacgRequest(
            "GET",
            "comics/" + id + "/order/" + ep + "/pages?page=" + page,
          )
        ).data.pages;
        images.push(
          ...data.docs.map(
            (/** @type {any} */ item) => picacgAvatarUrl(item.media) || "",
          ),
        );
        if (page >= Number(data.pages || 1)) break;
      }
      return { images };
    },
    onImageLoad: (url) => ({ url, headers: { "user-agent": "okhttp/3.8.1" } }),
    likeComic: async (id) => {
      await picacgRequest("POST", "comics/" + id + "/like", {});
    },
    loadComments: async (id, subId, page, replyTo) => {
      const data = (
        await picacgRequest(
          "GET",
          (replyTo
            ? "comments/" + replyTo + "/childrens"
            : "comics/" + id + "/comments") +
            "?page=" +
            page,
        )
      ).data.comments;
      return {
        comments: data.docs.map(picacgComment),
        maxPage: Number(data.pages || 1),
      };
    },
    sendComment: async (id, subId, text, replyTo) => {
      await picacgRequest(
        "POST",
        replyTo ? "comments/" + replyTo : "comics/" + id + "/comments",
        { content: text },
      );
    },
    likeComment: async (id, subId, commentId) => {
      await picacgRequest("POST", "comments/" + commentId + "/like", {});
    },
  },
  settings: {
    base_url: {
      location: "lines",
      title: "API地址(地址末尾不要添加斜杠)",
      type: "input",
      default: picacgDefaultApiUrl,
    },
    imageQuality: {
      type: "select",
      title: "Image quality",
      options: [
        {
          value: "original",
        },
        {
          value: "medium",
        },
        {
          value: "low",
        },
      ],
      default: "original",
    },
    appChannel: {
      location: "lines",
      type: "select",
      title: "App channel",
      options: [
        {
          value: "1",
        },
        {
          value: "2",
        },
        {
          value: "3",
        },
      ],
      default: "3",
    },
    favoriteSort: {
      type: "select",
      title: "Favorite sort",
      options: [
        {
          value: "dd",
          text: "New to old",
        },
        {
          value: "da",
          text: "Old to new",
        },
      ],
      default: "dd",
    },
  },
  translation: {
    en: {
      "API地址(地址末尾不要添加斜杠)": "API address (without a trailing slash)",
    },
    zh_CN: {
      "Picacg Random": "哔咔随机",
      "Picacg Latest": "哔咔最新",
      "Picacg H24": "哔咔日榜",
      "Picacg D7": "哔咔周榜",
      "Picacg D30": "哔咔月榜",
      "New to old": "新到旧",
      "Old to new": "旧到新",
      "Most likes": "最多喜欢",
      "Most nominated": "最多指名",
      Day: "日",
      Week: "周",
      Month: "月",
      Author: "作者",
      "Chinese Team": "汉化组",
      Categories: "分类",
      Tags: "标签",
      "Image quality": "图片质量",
      "App channel": "分流",
      "Favorite sort": "收藏排序",
      Sort: "排序",
    },
    zh_TW: {
      "Picacg Random": "哔咔隨機",
      "Picacg Latest": "哔咔最新",
      "Picacg H24": "哔咔日榜",
      "Picacg D7": "哔咔周榜",
      "Picacg D30": "哔咔月榜",
      "New to old": "新到舊",
      "Old to new": "舊到新",
      "Most likes": "最多喜歡",
      "Most nominated": "最多指名",
      Day: "日",
      Week: "周",
      Month: "月",
      Author: "作者",
      "Chinese Team": "漢化組",
      Categories: "分類",
      Tags: "標籤",
      "Image quality": "圖片質量",
      "App channel": "分流",
      "Favorite sort": "收藏排序",
      Sort: "排序",
    },
  },
  presentation: {
    showComments: true,
    buttons: [
      { id: "checkIn", location: "homeProfile" },
      { id: "autoCheckIn", location: "other" },
      { id: "imageQuality", location: "reading" },
      { id: "imageQuality", location: "reader" },
    ],
    dailyCheckIn: true,
    commentReplies: true,
    showTags: true,
    listTagGroups: ["tag", "tags", "category", "categories", "标签", "分类"],
    enrichMissingTags: true,
    localFavoriteOrders: { dd: "savedNewest", da: "savedOldest" },
    searchDefaultOrder: "dd",
    searchOrders: {
      dd: "新到旧",
      da: "旧到新",
      ld: "最多喜欢",
      vd: "最多指名",
    },
    favoriteOrders: ["dd", "da"],
    favoriteDefaultOrder: "dd",
    favoriteOrderSetting: "favoriteSort",
    imageQualitySetting: "imageQuality",
    imageQualityOptions: {
      original: "原图",
      medium: "中",
      low: "低",
    },
    imageQualityDefault: "original",
    requiresLogin: true,
  },
};
Hazuki.registerSource(source);
