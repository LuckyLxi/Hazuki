/*
# Source attribution

Adapted from [venera-configs/jm.js](https://github.com/venera-app/venera-configs/blob/e28e134074308c0006408272639a53b9af9ce9da/jm.js), commit `e28e134074308c0006408272639a53b9af9ce9da`.

The upstream repository did not contain a root license file at this commit. No additional license grant is asserted for the upstream code. Original comments and attribution are retained. Hazuki migration hooks use the project license.
*/
/// <reference path="../hazuki-source.d.ts" />
// @ts-check

const jmFallbackDomains = ['www.cdntwice.org', 'www.cdnsha.org', 'www.cdnaspa.cc', 'www.cdnntr.cc'];
const jmDefaultImageHost = 'https://cdn-msp.jmapinodeudzn.net';
const jmComicIdPattern = '^(?:jm)?(\\d{2,})$';
const jmUserAgent =
  'Mozilla/5.0 (Linux; Android 10; K; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/130.0.0.0 Mobile Safari/537.36';
let jmApiDomains = jmFallbackDomains.slice();
let jmImageHost = jmDefaultImageHost;
/** @type {Promise<{status: 'success' | 'alreadyCheckedIn' | 'skipped', message?: string}> | null} */
let jmCheckInPending = null;


/** @param {string} value */
function jmNormalizeUrl(value) {
  const url = value.trim();
  const match = /^(https:\/\/(?:[^/?#@]+@)?)([^:/?#]+):\d+(?=[/?#]|$)/i.exec(url);
  if (!match) return url;
  const host = match[2].toLowerCase();
  const hosts = [
    'www.jmcomic1.me', 'www.jmcomic2.me', 'www.jmcomic3.me',
    'www.jmapiproxyxxx.vip', 'www.cdntwice.org',
  ];
  const fragments = [
    'jmcomic', '18comic', 'jm365', 'jmapiproxy', 'cdn-msp',
    'cdnhth', 'cdntwice', 'cdnsha', 'cdnaspa', 'cdnntr',
  ];
  if (!hosts.includes(host) && !fragments.some((part) => host.includes(part))) return url;
  return `${match[1]}${match[2]}${url.slice(match[0].length)}`;
}

function jmBaseUrl() {
  const index = Number(Hazuki.settings.get('apiDomain') ?? '1') - 1;
  return `https://${jmApiDomains[index] || jmApiDomains[0]}`;
}

function jmBaseHeaders() {
  return {
    Accept: '*/*',
    'Accept-Encoding': 'gzip, deflate, br, zstd',
    'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    Connection: 'keep-alive',
    Origin: 'https://localhost',
    Referer: 'https://localhost/',
    'Sec-Fetch-Dest': 'empty',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'cross-site',
    'X-Requested-With': 'com.example.app',
  };
}

/** @param {number} time */
function jmApiHeaders(time) {
  const convert = Hazuki.convert;
  return {
    ...jmBaseHeaders(),
    Authorization: 'Bearer',
    'Sec-Fetch-Storage-Access': 'active',
    token: convert.hexEncode(convert.md5(convert.encodeUtf8(`${time}18comicAPPContent`))),
    tokenparam: `${time},2.0.16`,
    'User-Agent': jmUserAgent,
  };
}

function jmImageHeaders() {
  return {
    ...jmBaseHeaders(),
    Accept: 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    'Sec-Fetch-Dest': 'image',
    'Sec-Fetch-Mode': 'no-cors',
    'Sec-Fetch-Storage-Access': 'active',
    'User-Agent': jmUserAgent,
  };
}

/** @param {string} input @param {string} secret @returns {any} */
function jmDecodeData(input, secret) {
  const convert = Hazuki.convert;
  const key = convert.encodeUtf8(convert.hexEncode(convert.md5(convert.encodeUtf8(secret))));
  const text = convert.decodeUtf8(convert.decryptAesEcb(convert.decodeBase64(input), key));
  const start = text.search(/[\[{]/);
  const end = Math.max(text.lastIndexOf('}'), text.lastIndexOf(']'));
  if (start < 0 || end < start) throw new Error('invalid_jm_data');
  return JSON.parse(text.slice(start, end + 1));
}

/** @param {Record<string, unknown>} values */
function jmForm(values) {
  return Object.entries(values)
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`)
    .join('&');
}

/** @param {'GET' | 'POST'} method @param {string} path @param {Record<string, unknown>} values */
async function jmRequest(method, path, values = {}) {
  const time = Math.floor(Date.now() / 1000);
  const headers = jmApiHeaders(time);
  const url = jmNormalizeUrl(`${jmBaseUrl()}${path}`);
  const response =
    method === 'POST'
      ? await Hazuki.http.post(
          url,
          { ...headers, 'Content-Type': 'application/x-www-form-urlencoded' },
          jmForm(values),
        )
      : await Hazuki.http.get(url, headers);
  if (response.status === 401) throw Hazuki.error('AUTH_EXPIRED', 'JM session expired');
  if (response.status !== 200) throw new Error(`JM HTTP ${response.status}`);
  const envelope = JSON.parse(response.body);
  if (typeof envelope.data !== 'string') {
    throw new Error(envelope.errorMsg || envelope.msg || 'invalid_jm_data');
  }
  return jmDecodeData(envelope.data, `${time}185Hcomic3PAPP7R`);
}

async function jmMaybeCheckIn() {
  // Automatic check-in is awaited and cannot recurse through its own requests.
  if (Hazuki.settings.get('dailyCheckInTask') && Hazuki.storage.get('uid')) {
    try {
      await jmCheckIn();
    } catch (error) {
      Hazuki.log(String(error), 'warn');
    }
  }
}

/** @param {string} path */
async function jmGet(path) {
  await jmMaybeCheckIn();
  return jmRequest('GET', path);
}

/** @param {string} path @param {Record<string, unknown>} values */
async function jmPost(path, values) {
  await jmMaybeCheckIn();
  return jmRequest('POST', path, values);
}

async function jmRefreshDomains() {
  try {
    const response = await Hazuki.http.get(
      'https://rup4a04-c02.tos-cn-hongkong.bytepluses.com/newsvr-2025.txt',
      jmBaseHeaders(),
    );
    if (response.status !== 200) throw new Error(`JM domain HTTP ${response.status}`);
    const data = jmDecodeData(response.body, 'diosfjckwpqpdfjkvnqQjsik');
    const domains = jmArray(data.Server)
      .filter((domain) => typeof domain === 'string' && /^[a-z0-9.-]+$/i.test(domain))
      .slice(0, 4);
    if (!domains.length) throw new Error('invalid_jm_domains');
    jmApiDomains = domains;
  } catch (error) {
    jmApiDomains = jmFallbackDomains.slice();
    Hazuki.log(String(error), 'warn');
  }
}

async function jmRefreshImageHost() {
  const stream = String(Hazuki.settings.get('imageStream') ?? '1');
  const data = await jmRequest('GET', `/setting?${jmForm({ app_img_shunt: stream, express: '' })}`);
  if (typeof data.img_host === 'string' && data.img_host.trim()) {
    const host = data.img_host.trim();
    jmImageHost = jmNormalizeUrl(
      /^https?:\/\//i.test(host) ? host : `https://${host.replace(/^\/\//, '')}`
    ).replace(/\/+$/, '');
  }
}

/** @param {unknown} id */
function jmCoverUrl(id) {
  return jmNormalizeUrl(`${jmImageHost}/media/albums/${encodeURIComponent(String(id))}_3x4.jpg`);
}

/** @param {unknown} photo @param {unknown} uid */
function jmAvatarUrl(photo, uid = '') {
  const name = String(photo || (uid ? `${uid}.jpg` : '')).trim();
  if (!name) return '';
  if (/^https?:\/\//i.test(name)) return jmNormalizeUrl(name);
  if (name.startsWith('//')) return jmNormalizeUrl(`https:${name}`);
  return jmNormalizeUrl(name.startsWith('/media/')
    ? `${jmImageHost}${name}`
    : `${jmImageHost}/media/users/${name.replace(/^\/+/, '')}`);
}

/** @param {any} value @returns {any[]} */
function jmArray(value) {
  return Array.isArray(value) ? value : [];
}

/** @param {any} comic @returns {SourceComic} */
function jmParseComic(comic) {
  return {
    id: String(comic.id),
    title: String(comic.name ?? ''),
    cover: jmCoverUrl(comic.id),
    tags: [comic.category?.title, comic.category_sub?.title].filter(Boolean),
  };
}

/** @param {any} items @param {unknown} total @param {number} pageSize */
function jmComicPage(items, total, pageSize) {
  return {
    comics: jmArray(items).map(jmParseComic),
    maxPage: Math.ceil(Number(total || 0) / pageSize),
  };
}

/** @param {string} value */
function jmMatchComicId(value) {
  return new RegExp(jmComicIdPattern, 'i').exec(value.trim())?.[1] ?? null;
}

function jmToday() {
  // Keep the existing storage format so upgrades preserve today's check-in.
  const date = new Date();
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

async function jmPerformCheckIn() {
  const uid = Hazuki.storage.get('uid');
  if (!uid) throw Hazuki.error('AUTH_EXPIRED', 'Missing uid');
  if (Hazuki.storage.get('lastCheckInDate') === jmToday()) {
    return { status: /** @type {const} */ ('alreadyCheckedIn') };
  }
  const record = await jmRequest('GET', `/daily?${jmForm({ user_id: uid })}`);
  if (record.daily_id == null) throw new Error('invalid_daily_id');
  const result = await jmRequest('POST', '/daily_chk', { user_id: uid, daily_id: record.daily_id });
  if (!result.msg || result.status === 'fail' || result.status === 'error') {
    throw new Error(result.msg || 'invalid_check_in_result');
  }
  const status = /already|已[签到簽]+|今天已[签簽]/i.test(result.msg)
    ? /** @type {const} */ ('alreadyCheckedIn')
    : /** @type {const} */ ('success');
  await Hazuki.storage.set('lastCheckInDate', jmToday());
  return { status, message: String(result.msg) };
}

async function jmCheckIn() {
  if (jmCheckInPending) return jmCheckInPending;
  const pending = jmPerformCheckIn();
  jmCheckInPending = pending;
  try {
    return await pending;
  } finally {
    jmCheckInPending = null;
  }
}

/** @param {any} profile @param {unknown} uid */
function jmProfile(profile, uid, fallbackName = '') {
  const displayName = profile.nickname || profile.username || fallbackName;
  const avatarUrl = jmAvatarUrl(profile.photo || profile.avatar, uid);
  return {
    ...(displayName ? { displayName: String(displayName) } : {}),
    ...(avatarUrl ? { avatarUrl } : {}),
  };
}

/** @satisfies {HazukiSourceDefinition} */
const source = {
  id: 'jm',
  name: 'JMComic',
  version: '1.0.4',
  apiVersion: 1,

  async init() {
    if (Hazuki.settings.get('refreshDomainsOnStart')) await jmRefreshDomains();
    try {
      await jmRefreshImageHost();
    } catch (error) {
      Hazuki.log(String(error), 'warn');
    }
  },

  account: {
    async login(account, password) {
      const data = await jmRequest('POST', '/login', { username: account, password });
      if (!data.uid) throw new Error(data.msg || 'invalid_login_result');
      const profile = {
        nickname: data.nickname,
        username: data.username || account,
        photo: data.photo || data.avatar,
      };
      await Hazuki.storage.set('uid', data.uid);
      await Hazuki.storage.set('profile', profile);
      return jmProfile(profile, data.uid, account);
    },
    async loadProfile() {
      const uid = Hazuki.storage.get('uid');
      if (!uid) throw Hazuki.error('AUTH_EXPIRED', 'Missing uid');
      const profile = Hazuki.storage.get('profile') || {};
      const account = Hazuki.storage.get('account');
      return jmProfile(profile, uid, Array.isArray(account) ? String(account[0] ?? '') : '');
    },
    async logout() {
      for (const domain of new Set([...jmFallbackDomains, ...jmApiDomains])) {
        await Hazuki.cookies.delete(`https://${domain}/`);
      }
      for (const key of ['uid', 'profile', 'lastCheckInDate', 'avatar_url', 'display_name']) {
        await Hazuki.storage.delete(key);
      }
    },
    checkInStatus: async () => Hazuki.storage.get('lastCheckInDate') === jmToday(),
    checkIn: jmCheckIn,
  },

  explore: [
    {
      title: '禁漫天堂',
      type: 'multiPartPage',
      async load(page) {
        const data = await jmGet('/promote?page=0');
        return jmArray(data)
          .filter((section) => !['library', 'novels'].includes(section.type))
          .map((section) => ({
            title: section.title,
            comics: jmArray(section.content).map(jmParseComic),
            viewMore: `category:${section.title}@${section.type === 'category_id' ? section.slug : section.id}`,
            offersInitialComicsFilter: ['最新上市', '更新', '最新更新'].includes(section.title),
          }));
      },
    },
  ],

  category: {
    title: '禁漫天堂',
    parts: [
      {
        name: '每週必看',
        type: 'fixed',
        categories: ['每週必看'],
        itemType: 'category',
      },
      {
        name: '成人A漫',
        type: 'fixed',
        categories: [
          '最新A漫',
          '同人',
          '單本',
          '短篇',
          '其他類',
          '韓漫',
          '美漫',
          'Cosplay',
          '3D',
          '禁漫漢化組',
        ],
        itemType: 'category',
        categoryParams: [
          '0',
          'doujin',
          'single',
          'short',
          'another',
          'hanman',
          'meiman',
          'another_cosplay',
          '3D',
          '禁漫漢化組',
        ],
      },
      {
        name: '主題A漫',
        type: 'fixed',
        categories: [
          '無修正',
          '劇情向',
          '青年漫',
          '校服',
          '純愛',
          '人妻',
          '教師',
          '百合',
          'Yaoi',
          '性轉',
          'NTR',
          '女裝',
          '癡女',
          '全彩',
          '女性向',
          '完結',
          '純愛',
          '禁漫漢化組',
        ],
        itemType: 'search',
      },
      {
        name: '角色扮演',
        type: 'fixed',
        categories: [
          '御姐',
          '熟女',
          '巨乳',
          '貧乳',
          '女性支配',
          '教師',
          '女僕',
          '護士',
          '泳裝',
          '眼鏡',
          '連褲襪',
          '其他制服',
          '兔女郎',
        ],
        itemType: 'search',
      },
      {
        name: '特殊PLAY',
        type: 'fixed',
        categories: [
          '群交',
          '足交',
          '束縛',
          '肛交',
          '阿黑顏',
          '藥物',
          '扶他',
          '調教',
          '野外露出',
          '催眠',
          '自慰',
          '觸手',
          '獸交',
          '亞人',
          '怪物女孩',
          '皮物',
          'ryona',
          '騎大車',
        ],
        itemType: 'search',
      },
      {
        name: '特殊PLAY',
        type: 'fixed',
        categories: ['CG', '重口', '獵奇', '非H', '血腥暴力', '站長推薦'],
        itemType: 'search',
      },
    ],
  },

  categoryComics: {
    async load(category, param, options, page) {
      if (category === '每週必看') {
        const data = await jmGet(
          `/week/filter?${jmForm({ id: options[0], type: options[1], page: 0 })}`,
        );
        return { comics: jmArray(data.list).map(jmParseComic), maxPage: 1 };
      }
      const data = await jmGet(
        `/categories/filter?${jmForm({ o: options[0] || 'mr', c: param ?? category, page })}`,
      );
      return jmComicPage(data.content, data.total, 80);
    },
    async optionLoader(category, param) {
      if (category !== '每週必看') {
        return [
          {
            label: '排序',
            options: [
              'mr-最新',
              'mv-總排行',
              'mv_m-月排行',
              'mv_w-周排行',
              'mv_t-日排行',
              'mp-最多圖片',
              'tf-最多喜歡',
            ],
          },
        ];
      }
      const data = await jmGet('/week');
      return [
        {
          label: '時間',
          options: jmArray(data.categories).map((option) => `${option.id}-${option.time}`),
        },
        { label: '類型', options: ['manga-日漫', 'hanman-韓漫', 'another-其他'] },
      ];
    },
    ranking: {
      options: ['mv-總排行', 'mv_m-月排行', 'mv_w-周排行', 'mv_t-日排行'],
      load: (option, page) =>
        jmGet(`/categories/filter?${jmForm({ o: option, c: '0', page })}`).then((data) =>
          jmComicPage(data.content, data.total, 80),
        ),
    },
  },

  search: {
    async load(keyword, options, page) {
      const id = jmMatchComicId(keyword);
      if (id) {
        try {
          // ID lookup uses the album API; it does not depend on keyword results.
          const album = await jmGet(`/album?${jmForm({ id })}`);
          if (typeof album?.name !== 'string' || !album.name.trim()) {
            throw new Error('invalid_jm_album');
          }
          return {
            comics: page === 1 ? [jmParseComic({ ...album, id })] : [],
            maxPage: 1,
          };
        } catch (error) {
          // Keep the host's ordinary keyword fallback when an ID is unavailable.
          Hazuki.log(String(error), 'warn');
        }
      }
      const query = jmForm({ search_query: keyword.trim(), o: options[0] || 'mr' }).replace(
        /%20/g,
        '+',
      );
      const data = await jmGet(`/search?${query}${page > 1 ? `&page=${page}` : ''}`);
      return jmComicPage(data.content, data.total, 80);
    },
  },

  favorites: {
    singleFolderForSingleComic: true,
    async loadComics(page, folderId) {
      const data = await jmGet(
        `/favorite?${jmForm({ folder_id: folderId ?? '0', page, o: Hazuki.settings.get('favoriteOrder') || 'mr' })}`,
      );
      return jmComicPage(data.list, data.total, 20);
    },
    async loadFolders(comicId) {
      const data = await jmGet('/favorite');
      /** @type {Record<string, string>} */
      const folders = { 0: '全部' };
      for (const folder of data.folder_list ?? [])
        folders[String(folder.FID)] = String(folder.name);
      return { folders, favorited: [] };
    },
    async addFolder(name) {
      await jmPost('/favorite_folder', { type: 'add', folder_name: name });
    },
    async deleteFolder(id) {
      await jmPost('/favorite_folder', { type: 'del', folder_id: id });
    },
    async addOrDelFavorite(comicId, folderId, adding, favoriteId) {
      await jmPost('/favorite', { aid: comicId });
      if (adding)
        await jmPost('/favorite_folder', {
          type: 'move',
          folder_id: folderId,
          aid: comicId,
        });
    },
  },

  comic: {
    async loadInfo(comicId) {
      const id = jmMatchComicId(comicId) ?? comicId.trim().replace(/^jm/i, '');
      const data = await jmGet(`/album?${jmForm({ id })}`);
      /** @type {Record<string, string>} */
      const chapters = {};
      for (const chapter of [...(data.series ?? [])].sort((a, b) => a.sort - b.sort)) {
        chapters[String(chapter.id)] = String(chapter.name ?? '').trim() || `第${chapter.sort}話`;
      }
      if (!Object.keys(chapters).length) chapters[id] = '第1話';
      const date = data.addtime ? new Date(Number(data.addtime) * 1000) : null;
      return {
        id,
        title: String(data.name ?? ''),
        cover: jmCoverUrl(id),
        description: String(data.description ?? ''),
        likesCount: Number(data.likes || 0),
        chapters,
        tags: {
          Author: data.author ?? [],
          Tag: data.tags ?? [],
          Work: data.works ?? [],
          Actor: data.actors ?? [],
          View: data.total_views ? [String(data.total_views)] : [],
        },
        infoFields: [
          { label: { zh: '作者', en: 'Author' }, values: data.author ?? [], action: 'search' },
          { label: { zh: '标签', en: 'Tags' }, values: data.tags ?? [], action: 'search' },
          { label: { zh: '作品', en: 'Work' }, values: data.works ?? [], action: 'search' },
          { label: { zh: '角色', en: 'Characters' }, values: data.actors ?? [], action: 'search' },
        ],
        viewsCount: data.total_views ?? '',
        headerStats: [
          { text: { zh: `${Number(data.likes || 0)}点赞`, en: `${Number(data.likes || 0)} likes` }, action: 'like' },
          { text: data.total_views == null ? '' : { zh: `${data.total_views}浏览量`, en: `${data.total_views} views` } },
        ],
        recommend: jmArray(data.related_list).map(jmParseComic),
        isFavorite: Boolean(data.is_favorite),
        isLiked: Boolean(data.liked),
        updateTime: date ? `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}` : '',
      };
    },
    async loadEp(comicId, chapterId) {
      const data = await jmGet(`/chapter?${jmForm({ id: chapterId })}`);
      return {
        images: jmArray(data.images).map(
          (name) => jmNormalizeUrl(`${jmImageHost}/media/photos/${encodeURIComponent(chapterId)}/${name}`),
        ),
      };
    },
    onImageLoad(url, comicId, chapterId) {
      const id = Number(chapterId);
      const name = (url.split('?')[0].split('/').pop() || '').replace(/\.[^.]+$/, '');
      let segments = 0;
      if (!/\.gif(?:\?|$)/i.test(url)) {
        if (id >= 220980 && id < 268850) segments = 10;
        else if (id >= 268850) {
          const convert = Hazuki.convert;
          const hash = convert.hexEncode(convert.md5(convert.encodeUtf8(`${id}${name}`)));
          segments = (hash.charCodeAt(hash.length - 1) % (id > 421926 ? 8 : 10)) * 2 + 2;
        }
      }
      return { url: jmNormalizeUrl(url), headers: jmImageHeaders(), ...Hazuki.images.reverseVerticalTiles(segments) };
    },
    async likeComic(id, isLike) {
      const result = await jmPost('/like', { id });
      if (result.code !== 200 || result.status === 'error')
        throw new Error(result.msg || 'Failed to like/unlike comic');
    },
    async loadComments(id, subId, page, replyTo) {
      const data = await jmGet(`/forum?${jmForm({ mode: 'manhua', aid: id, page })}`);
      return {
        comments: jmArray(data.list).map((comment) => ({
          id: String(comment.CID ?? comment.id ?? ''),
          avatar: jmAvatarUrl(comment.photo),
          userName: String(comment.username ?? ''),
          time: String(comment.addtime ?? ''),
          content: String(comment.content ?? '').replace(/<[^>]*>/g, ''),
        })),
        maxPage: Math.ceil(Number(data.total || 0) / 6),
      };
    },
    async sendComment(id, subId, text, replyTo) {
      const result = await jmPost('/comment', {
        aid: id,
        comment: text,
        status: 'undefined',
      });
      if (result.status === 'fail') throw new Error(result.msg || 'Failed to send comment');
    },
  },

  settings: {
    refreshDomainsOnStart: {
      location: 'lines',
      title: 'Refresh Domain List on Startup',
      type: 'switch',
      default: true,
    },
    apiDomain: {
      location: 'lines',
      onChanged: jmRefreshImageHost,
      title: 'Api Domain',
      type: 'select',
      options: [
        {
          value: '1',
        },
        {
          value: '2',
        },
        {
          value: '3',
        },
        {
          value: '4',
        },
      ],
      default: '1',
    },
    imageStream: {
      location: 'lines',
      onChanged: jmRefreshImageHost,
      title: 'Image Stream',
      type: 'select',
      options: [
        {
          value: '1',
        },
        {
          value: '2',
        },
        {
          value: '3',
        },
        {
          value: '4',
        },
      ],
      default: '1',
    },
    favoriteOrder: {
      title: 'Favorite Order',
      type: 'select',
      options: [
        {
          value: 'mr',
          text: 'Add Time',
        },
        {
          value: 'mp',
          text: 'Update Time',
        },
      ],
      default: 'mr',
    },
    dailyCheckInTask: {
      title: 'Daily Check-in Task',
      type: 'switch',
      default: false,
    },
  },
  translation: {
    en: {
      '刷新线路': 'Refresh lines',
      '线路已刷新': 'Lines refreshed',
    },
    zh_CN: {
      'Refresh Domain List': '刷新域名列表',
      Refresh: '刷新',
      'Refresh Domain List on Startup': '启动时刷新域名列表',
      'Api Domain': 'Api域名',
      'Image Stream': '图片分流',
      'Favorite Order': '收藏夹排序',
      'Daily Check-in Task': '每日自动签到',
      'Manual Check-In': '手动签到',
      'Check-In': '签到',
      'Add Time': '添加时间',
      'Update Time': '更新时间',
      All: '全部',
      Author: '作者',
      Tag: '标签',
      Work: '作品',
      Actor: '角色',
      View: '浏览量',
    },
    zh_TW: {
      'Refresh Domain List': '刷新域名列表',
      Refresh: '刷新',
      'Refresh Domain List on Startup': '啟動時刷新域名列表',
      'Api Domain': 'Api域名',
      'Image Stream': '圖片分流',
      'Favorite Order': '收藏夾排序',
      'Daily Check-in Task': '每日自動簽到',
      'Manual Check-In': '手動簽到',
      'Check-In': '簽到',
      'Add Time': '添加時間',
      'Update Time': '更新時間',
      All: '全部',
      Author: '作者',
      Tag: '標籤',
      Work: '作品',
      Actor: '角色',
      View: '瀏覽量',
    },
  },
  presentation: {
    showComments: true,
    buttons: [
      { id: 'checkIn', location: 'homeProfile' },
      { id: 'autoCheckIn', location: 'other' },
      { id: 'copyComicId', location: 'comicDetailInfo' },
      { id: 'relatedComics', location: 'comicDetailTabs' },
    ],
    directComicIdRules: { patterns: [jmComicIdPattern], extractDigits: true },
    dailyRecommendation: { searchOrder: 'mr' },
    showComicId: true,
    listTagGroups: ['Tag'],
    favoriteOrderAliases: { '-datetime_updated': 'mp' },
    localFavoriteOrders: { mr: 'savedNewest', mp: 'updatedNewest' },
    dailyCheckIn: true,
    searchDefaultOrder: 'mr',
    searchOrders: {
      mr: {
        zh: '最新',
        en: 'Latest',
      },
      mv: {
        zh: '总排行',
        en: 'Top overall',
      },
      mv_m: {
        zh: '月排行',
        en: 'Top monthly',
      },
      mv_w: {
        zh: '周排行',
        en: 'Top weekly',
      },
      mv_t: {
        zh: '日排行',
        en: 'Top daily',
      },
      mp: {
        zh: '最多图片',
        en: 'Most images',
      },
      tf: {
        zh: '最多喜欢',
        en: 'Most likes',
      },
    },
    favoriteOrders: ['mr', 'mp'],
    favoriteDefaultOrder: 'mr',
    favoriteOrderSetting: 'favoriteOrder',
    actions: [
      {
        id: 'refreshLines',
        title: '刷新线路',
        location: 'lines',
      },
    ],
  },

  actions: {
    async refreshLines() {
      await jmRefreshDomains();
      await jmRefreshImageHost();
      return '线路已刷新';
    },
  },
  lines: { snapshot: () => ({ apiDomains: jmApiDomains.slice(), imageHost: jmImageHost }) },
};

Hazuki.registerSource(source);
