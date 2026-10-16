/// <reference path="../hazuki-source.d.ts" />
// @ts-check

/*
# Source attribution

Original Hazuki Source API v1 plugin for 熱辣漫畫 / 热辣漫画 (https://www.manga2026.com/).
Written for this repository; not adapted from an upstream venera-configs source and
containing no third-party source code. Two pieces are standard published algorithms
rather than site code: the AES-128 S-box constants (FIPS 197) and the AES-128-CBC
decryption routine. Hazuki integration uses the project license (GPL-3.0); see LICENSE.

Site interface used here, all observed from the public website:
  search    GET /api/v3/search/comic?offset&platform=2&limit=12&q&free_type=1|2
  detail    GET /comic/<path_word>                    (server-rendered HTML)
  chapters  GET /comicdetail/<path_word>/chapters      (encrypted JSON)
  reader    GET /comic/<path_word>/chapter/<uuid>      (HTML + encrypted page list)

Encrypted payloads are `iv(16 chars) + hex(ciphertext)`; the cipher is AES-128-CBC
with PKCS#7 padding and the key is the page's own `cct` value (also published as the
`disposable` attribute on the detail page). Reading needs no account: the "試看"
banner is only a sign-up nag and the full page list is present for guests.
*/

const relamanhuaOrigin = "https://www.manga2026.com";
/** Used only if a page stops publishing its own key. */
const relamanhuaFallbackKey = "0p0zzpvv.nmn.oop";
const relamanhuaPageSize = 12;
const relamanhuaCatalogLimit = 50;
const relamanhuaRecommendLimit = 60;
const relamanhuaUserAgent =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
/** Base for API-returned image paths (the site's own VUE_APP_ImageSplitUrl). */
const relamanhuaAssetHost = "https://s3.mangafunb.fun";
/** The desktop site reports this build to the account API. */
const relamanhuaClientVersion = "2025.12.10";
/** Ranking tabs on /rank that hold comics (cartoon and korea tabs are separate). */
const relamanhuaRankTabs = [
  ["day", "免費日榜"],
  ["week", "免費週榜"],
  ["month", "免費月榜"],
  ["overall", "免費總榜"],
  ["pay-day", "付費日榜"],
  ["pay-week", "付費週榜"],
  ["pay-month", "付費月榜"],
  ["pay-overall", "付費總榜"],
  ["korea-day", "韓漫日榜"],
  ["korea-week", "韓漫週榜"],
  ["korea-month", "韓漫月榜"],
  ["korea-overall", "韓漫總榜"],
];
/** Theme slugs from /comics, paired with the labels the site itself renders. */
const relamanhuaThemes = [
  ["aiqing", "愛情"],
  ["huanlexiang", "歡樂向"],
  ["maoxian", "冒險"],
  ["qihuan", "奇幻"],
  ["baihe", "百合"],
  ["xiaoyuan", "校园"],
  ["kehuan", "科幻"],
  ["dongfang", "東方"],
  ["danmei", "耽美"],
  ["gedou", "格鬥"],
  ["teenslove", "TL"],
  ["shenghuo", "生活"],
  ["qingxiaoshuo", "轻小说"],
  ["qita", "其他"],
  ["xuanyi", "悬疑"],
  ["mengxi", "萌系"],
  ["shengui", "神鬼"],
  ["zhichang", "职场"],
  ["zhiyu", "治愈"],
  ["jiecao", "节操"],
  ["sige", "四格"],
  ["gaoxiao", "搞笑"],
  ["changtiao", "長條"],
  ["jingji", "竞技"],
  ["mohuan", "魔幻"],
  ["jianniang", "舰娘"],
  ["weiniang", "伪娘"],
  ["rexue", "热血"],
  ["jingsong", "惊悚"],
  ["meishi", "美食"],
  ["xingzhuanhuan", "性转换"],
  ["lizhi", "励志"],
  ["yinyuewudao", "音乐舞蹈"],
  ["hougong", "後宮"],
  ["zhentan", "侦探"],
  ["COLOR", "彩色"],
  ["aa", "AA"],
  ["yishijie", "异世界"],
  ["lishi", "历史"],
  ["chuanyue", "穿越"],
  ["jizhan", "机战"],
  ["zhanzheng", "战争"],
  ["dushi", "都市"],
  ["chongsheng", "重生"],
  ["comiket102", "C102"],
  ["kongbu", "恐怖"],
  ["shengcun", "生存"],
  ["comiket103", "C103"],
  ["comiket104", "C104"],
  ["comiket100", "C100"],
  ["wuxia", "武侠"],
  ["comiket101", "C101"],
  ["comiket99", "C99"],
  ["comiket97", "C97"],
  ["comiket105", "C105"],
  ["zhaixi", "宅系"],
  ["comiket96", "C96"],
  ["comiket106", "C106"],
  ["comiket107", "C107"],
  ["C98", "C98"],
  ["comiket95", "C95"],
  ["zhuansheng", "转生"],
  ["comiket108", "C108"],
  ["fate", "FATE"],
  ["Uncensored", "無修正"],
  ["xianxia", "仙侠"],
  ["loveLive", "LoveLive"],
  ["zazhifuzengxiezhenji", "雜誌附贈寫真集"],
];

/** Paid comic tags from /filter?point=1; disabled entries are omitted. */
const relamanhuaFemaleTags = [
  ["female_big_breasts", "大胸(女)"],
  ["female_uniformsole_female", "單女主(女)"],
  ["female_nakadashi", "中出(女)"],
  ["female_blowjob", "口交(女)"],
  ["female_uniformstockings", "絲襪/長筒襪(女)"],
  ["female_schoolgirl_uniform", "女學生制服(女)"],
  ["female_lolicon", "蘿莉控/蘿莉(女)"],
  ["female_anal", "肛交(女)"],
  ["female_ahegao", "高潮臉|啊嘿顏(女)"],
  ["female_milf", "熟女(女)"],
  ["female_huge_breasts", "巨乳(女)"],
  ["female_twintails", "雙馬尾(女)"],
  ["female_netorare", "寢取/NTR/綠帽/牛頭人(女)"],
  ["female_rape", "強暴(女)"],
  ["ponytail", "馬尾(女)"],
  ["female_paizuri", "乳交(女)"],
  ["female_bondage", "捆綁(女)"],
  ["female_glasses", "眼鏡(女)"],
  ["female_x_ray", "透視(女)"],
  ["female_impregnation", "受孕(女)"],
  ["female_kemonomimi", "獸耳(女)"],
  ["female_sex_toys", "情趣玩具(女)"],
  ["female_hairy", "陰毛濃郁(女)"],
  ["female_double_penetration", "雙插入(女)"],
  ["female_collar", "項圈(女)"],
  ["female_defloration", "破處(女)"],
  ["female_swimsuit", "泳裝(女)"],
  ["female_femdom", "女王(女)"],
  ["female_dark_skin", "黑皮(女)"],
  ["female_big_ass", "肥臀(女)"],
  ["female_futanari", "扶他/扶她(女)"],
  ["female_pantyhose", "褲襪(女)"],
  ["female_bikini", "比基尼(女)"],
  ["female_gloves", "手套(女)"],
  ["female_mind_control", "催眠(女)"],
  ["female_cheating", "偷情(女)"],
  ["female_yuri", "百合(女)"],
  ["female_pregnant", "懷孕(女)"],
  ["female_lactation", "乳汁(女)"],
  ["female_beauty_mark", "美人痣(女)"],
  ["female_kissing", "親吻(女)"],
  ["female_lingerie", "內衣(女)"],
  ["female_sweating", "汗流浹背(女)"],
  ["female_sister", "姐妹(女)"],
  ["female_tentacles", "觸手(女)"],
  ["female_masturbation", "自慰(女)"],
  ["verylonghair", "很長的頭髮(女)"],
  ["female_small_breasts", "平胸/貧乳(女)"],
  ["female_handjob", "擼/拤(女)"],
  ["female_fingering", "捻弄(女)"],
  ["female_females_only", "全女性(女)"],
  ["female_mother", "母(女)"],
  ["female_horns", "犄角(女)"],
  ["female_unusual_pupils", "異形瞳(女)"],
  ["female_mind_break", "意識崩壞(女)"],
  ["female_exhibitionism", "暴露癖(女)"],
  ["female_maid", "女僕(女)"],
  ["female_footjob", "足交(女)"],
  ["female_gyaru", "辣妹|太妹(女)"],
  ["female_piercing", "穿刺(女)"],
  ["female_harem", "後宮(女)"],
  ["female_bunny_girl", "兔女郎(女)"],
  ["female_big_areolae", "大乳暈(女)"],
  ["tail0", "尾巴(女)"],
  ["female_demon_girl", "惡魔娘(女)"],
  ["female_filming", "錄像(女)"],
  ["halo", "光環(女)"],
  ["female_cunnilingus", "舌功/prpr(女)"],
  ["female_elf", "精靈(女)"],
  ["female_prostitution", "賣淫/援交(女)"],
  ["female_squirting", "潮吹(女)"],
  ["female garter belt", "吊襪帶(女)"],
  ["female_stomach_deformation", "一步到胃(女)"],
  ["female_urination", "放尿(女)"],
  ["female_blackmail", "脅迫(女)"],
  ["female_catgirl", "貓娘(女)"],
  ["female_gag", "塞口球(女)"],
  ["female_kimono", "和服(女)"],
  ["female_teacher", "教師(女)"],
  ["female_bukkake", "精子風呂/精液浴(女)"],
  ["female_blindfold", "蒙眼(女)"],
  ["female_drugs", "嗑藥(女)"],
  ["female_group", "群交(女)"],
  ["female_sole_dickgirl", "大屌萌妹(女)"],
  ["female_bbw", "肥婆(女)"],
  ["female_tanlines", "日曬痕(女)"],
  ["female_crotch_tattoo", "胯部紋身|淫紋(女)"],
  ["female_corruption", "黑化(女)"],
  ["female_leotard", "緊身褲(女)"],
  ["female_hidden_sex", "公眾場合躲著做愛(女)"],
  ["female_deepthroat", "深喉(女)"],
  ["eye-overingbang", "遮眼劉海(女)"],
  ["female_blowjob_face", "口交顏(女)"],
  ["female_inflation", "肚子膨大(女)"],
  ["female_scat", "脫糞/排便(女)"],
  ["female_breast_feeding", "喂奶(女)"],
  ["female_wings", "翅膀(女)"],
  ["female_rimjob", "舔肛/舔菊花(女)"],
  ["female_big_penis", "大根/大jj(女)"],
  ["female_sleeping", "入眠中/夢淫(女)"],
  ["female_tomboy", "假小子(女)"],
  ["femaleinvertednipples", "乳頭內陷(女)"],
  ["female_thigh_high_boots", "長靴(女)"],
  ["female_fox_girl", "狐女(女)"],
  ["female_latex", "緊身皮衣/膠衣(女)"],
  ["female_bestiality", "獸交|人獸(女)"],
  ["female_monster_girl", "怪物娘(女)"],
  ["female_bodysuit", "連身衣(女)"],
  ["female_incest", "亂倫(女)"],
  ["female_torture", "調教(女)"],
  ["female_school_swimsuit", "死庫水/學校泳裝(女)"],
  ["female_big_nipples", "大乳頭(女)"],
  ["female_magical_girl", "魔法少女(女)"],
  ["female_business_suit", "西裝(女)"],
  ["female_drunk", "醉酒(女)"],
  ["female_tall_girl", "女孩身材較高(女)"],
  ["female_breast_expansion", "乳房擴張(女)"],
  ["female_hairy_armpits", "腋窩有毛(女)"],
  ["female_body_writing", "身上寫字(女)"],
  ["female_cervix_penetration", "子宮play(女)"],
  ["female_shemale", "人妖(女)"],
  ["female_daughter", "女兒(女)"],
  ["female_slave", "奴隸(女)"],
  ["nun", "修女(女)"],
  ["nipple stimulation", "刺激乳頭(女)"],
  ["vtuber", "虛擬主播(女)"],
  ["female_oralcumshot", "口內射精(女)"],
  ["hairbuns", "包包頭(女)"],
  ["female_bdsm", "sm捆綁(女)"],
  ["female_shibari", "捆綁(日式)(女)"],
  ["female_apron", "圍裙(女)"],
  ["female_double_blowjob", "雙人口交/雙人侍奉(女)"],
  ["female_oyakodon", "親子蓋飯/母女(女)"],
  ["female_smell", "臭(女)"],
  ["female_bisexual", "雙性戀(女)"],
  ["female_nurse", "護士(女)"],
  ["female_muscle", "肌肉(女)"],
  ["female_bloomers", "燈籠褲(女)"],
  ["female_miko", "巫女(女)"],
  ["female_enema", "灌腸(女)"],
  ["female_ryona", "ryona/殘虐快感(女)"],
  ["female_furry", "獸娘(女)"],
  ["female_gokkun", "吞精(女)"],
  ["strapon", "女用穿戴假陽具(女)"],
  ["female_condom", "避孕套(女)"],
  ["female_cowgirl", "牛娘/奶牛裝(女)"],
  ["female_leg_lock", "雙腿鎖腰(女)"],
  ["female_tribadism", "女同性交/磨鏡(女)"],
  ["female_transformation", "變身(女)"],
  ["female_oppai loli", "童顏巨乳(女)"],
  ["female_humiliation", "羞辱(女)"],
  ["female_emotionless_sex", "無快感做愛(女)"],
  ["female_dickgirl_on_dickgirl", "大屌萌妹互爆(女)"],
  ["female_possession", "附身(女)"],
  ["female_cosplaying", "cosplay/角色扮演/cos(女)"],
  ["female_body_modification", "肉體改造(女)"],
  ["female_dick_growth", "女性長出jj(女)"],
  ["female_spanking", "打屁股(女)"],
  ["female_gaping", "合不攏腿(女)"],
  ["female_birth", "分娩(女)"],
  ["female_facesitting", "騎臉(女)"],
  ["female_pasties", "乳貼(女)"],
  ["female_guro", "糞|血腥獵奇(女)"],
  ["female_milking", "擠奶(女)"],
  ["female_oni", "鬼(女)"],
  ["female_chikan", "癡漢(女)"],
  ["female_tiara", "頭冠(女)"],
  ["female_urethra_insertion", "尿道插入(女)"],
  ["female_nipple_fuck", "乳頭交(女)"],
  ["female_facial", "顏射(女)"],
  ["female_male_on_dickgirl", "漢子乾大屌萌妹(女)"],
  ["female_snuff", "虐殺(女)"],
  ["mouthmask", "口罩(女)"],
  ["female_aunt", "姨媽(女)"],
  ["female_chinese_dress", "旗袍(女)"],
  ["female_sumata", "素股/蹭蹭不進去(女)"],
  ["female_asphyxiation", "窒息(女)"],
  ["female_amputee", "截肢(女)"],
  ["female_farting", "放屁(女)"],
  ["female_solo_action", "自慰表演(女)"],
  ["female_tracksuit", "運動服(女)"],
  ["female_fisting", "拳交(女)"],
  ["female_dark_nipples", "黑葡萄|暗色乳頭(女)"],
  ["tailplug", "尾塞(女)"],
  ["female_moral_degeneration", "墮落/背德(女)"],
  ["female_cousin", "表妹表姐(女)"],
  ["female_bike_shorts", "騎行褲(女)"],
  ["female_triple_penetration", "三通/三插入(女)"],
  ["female_hotpants", "熱褲(女)"],
  ["female_nose_hook", "鼻鉤(女)"],
  ["shimaidon", "姉妹丼(女)"],
  ["female_witch", "女巫(女)"],
  ["female_clothed_paizuri", "著衣乳交(女)"],
  ["female_prolapse", "脫垂/脫肛/宮脫(女)"],
  ["female_swinging", "換妻(女)"],
  ["female_niece", "外甥(女)"],
  ["female_masked_face", "蒙面(女)"],
  ["female_chloroform", "麻醉(女)"],
  ["female_yandere", "病嬌(女)"],
  ["female_machine", "性愛機器(女)"],
  ["female_piss_drinking", "飲尿/聖水(女)"],
  ["female_twins", "雙胞胎(女)"],
  ["female_multiple_paizuri", "多人乳交(女)"],
  ["female_cheerleader", "啦啦隊(女)"],
  ["female_public_use", "公眾便所/肉便器/RBQ(女)"],
  ["female_bride", "新娘(女)"],
  ["female_big_clit", "大陰蒂(女)"],
  ["female_eggs", "產卵(女)"],
  ["female_robot", "機器人(女)"],
  ["multipleorgasms", "多次高潮(女)"],
  ["female_large_insertions", "巨物插入(女)"],
  ["female_big_balls", "大睾丸(女)"],
  ["female_eyepatch", "單眼罩/獨眼罩(女)"],
  ["female_parasite", "寄生(女)"],
  ["female_ball_sucking", "吸吮睾丸(女)"],
  ["female_skinsuit", "畫皮(女)"],
  ["female_blood", "血腥(女)"],
  ["female_vore", "vore/丸吞(女)"],
  ["female_kunoichi", "女忍者(女)"],
  ["female_christmas", "聖誕裝(女)"],
  ["female_giantess", "女巨人(女)"],
  ["petplay", "寵物扮演(女)"],
  ["female_all_the_way_through", "一氣貫通(女)"],
  ["female_insect", "蟲(女)"],
  ["female_dog_girl", "犬娘(女)"],
  ["female_tickling", "撓癢癢(女)"],
  ["female_widow", "寡婦/未亡人(女)"],
  ["female_thick_eyebrows", "濃眉毛(女)"],
  ["female_chastity_belt", "貞操帶(女)"],
  ["female_double_vaginal", "雙龍入洞(女)"],
  ["female_huge_penis", "巨根(女)"],
  ["schoolgymuniform", "學校體育制服(女)"],
  ["female_living_clothes", "活化衣服(女)"],
  ["female_unusual_teeth", "特殊牙齒/尖牙(女)"],
  ["female_slime", "史萊姆(女)"],
  ["female_stuck_in_wall", "壁尻(女)"],
  ["female_foot_licking", "戀足/舔腳(女)"],
  ["genderchange", "性別轉換(女)"],
  ["female_freckles", "雀斑(女)"],
  ["female_wolf_girl", "狼女(女)"],
  ["female_lab_coat", "實驗服/白大褂(女)"],
  ["female_ghost", "幽靈(女)"],
  ["female_policewoman", "女警(女)"],
  ["female_eyemask", "眼罩(女)"],
  ["female_military", "軍裝(女)"],
  ["female_dickgirls_only", "全大屌萌妹(女)"],
  ["female_heterochromia", "異瞳/雙色瞳(女)"],
  ["female_shimapan", "條紋內褲(女)"],
  ["female_armpit_licking", "舔腋窩(女)"],
  ["makeup", "化妝(女)"],
  ["long_tongue", "長舌(女)"],
  ["female_orgasm_denial", "拒絕高潮(女)"],
  ["female_angel", "天使(女)"],
  ["female_electric_shocks", "電擊(女)"],
  ["female_vampire", "吸血鬼(女)"],
  ["female_harness", "拘束衣(女)"],
  ["female_voyeurism", "偷窺(女)"],
  ["female_bodystocking", "連體襪(女)"],
  ["female_coprophagia", "食糞/黃金(女)"],
  ["female_closed_eyes", "閉眼(女)"],
  ["female_wet_clothes", "濕身(女)"],
  ["female_gothic_lolita", "哥特蘿莉(女)"],
  ["female_armpit_sex", "腋交(女)"],
  ["female_gymshorts", "運動短褲(女)"],
  ["female_tights", "緊身衣(女)"],
  ["female_corset", "束腰/腰封(女)"],
  ["female_vomit", "嘔吐(女)"],
  ["female_autofellatio", "自體口交(女)"],
  ["female_assjob", "臀交(女)"],
  ["female_age_progression", "年齡變化(女)"],
  ["female_dark_sclera", "黑色眼白(女)"],
  ["female_diaper", "尿布(女)"],
  ["female_metal_armor", "盔甲/鎧甲(女)"],
  ["female_crossdressing", "異裝癖(女)"],
  ["female_clit_growth", "陰蒂膨大(女)"],
  ["female_double_anal", "雙龍入菊(女)"],
  ["female_sundress", "背心裙(女)"],
  ["female_tutor", "家庭教師(女)"],
  ["female_pubic_stubble", "私處剃毛(女)"],
  ["female_slime_girl", "史萊姆娘(女)"],
  ["female_ftail_plug", "假尾巴(女)"],
  ["female_oil", "油(女)"],
  ["female_scar", "疤痕(女)"],
  ["female_human_cattle", "人間牧場(女)"],
  ["female_waitress", "女僕/女服務員(女)"],
  ["female_wormhole", "蟲洞/空間轉移(女)"],
  ["female_snake_girl", "蛇女(女)"],
  ["female_fairy", "妖精(女)"],
  ["female_minigirl", "拇指姑娘(女)"],
  ["female_sockjob", "絲襪play(女)"],
  ["female_brain_fuck", "腦交(女)"],
  ["female_underwater", "水下(女)"],
  ["female_absorption", "吸收(女)"],
  ["female_crown", "王冠/皇冠/公主冠(女)"],
  ["personalityexcretion", "人格排泄(女)"],
  ["female_inseki", "無血緣亂倫(女)"],
  ["female_selfcest", "selfcest/自交(女)"],
  ["female_unbirth", "胎兒(女)"],
  ["female_cum_swap", "精液分享(女)"],
  ["female_ffm_threesome", "一龍二鳳(女)"],
  ["female_petrification", "石化(女)"],
  ["female_pillory", "枷鎖(女)"],
  ["female_bandages", "繃帶(女)"],
  ["female_fundoshi", "兜襠布(女)"],
  ["female_ttf_threesome", "一女二扶她(女)"],
  ["female_horse_girl", "馬娘(女)"],
  ["female_mecha_girl", "機娘(女)"],
  ["female_human_on_furry", "人x獸娘/人x獸男(女)"],
  ["female_vaginal_sticker", "穴口貼紙(女)"],
  ["female_anal_birth", "肛門生產(女)"],
  ["female_saliva", "唾液(女)"],
  ["female_doll_joints", "球關節/玩偶關節(女)"],
  ["female_fft_threesome", "二女一扶她(女)"],
  ["female_autopaizuri", "自取其乳(女)"],
  ["female_mosaic_censorship", "馬賽克審查(女)"],
  ["female_tube", "導管/插管(女)"],
  ["female_whip", "鞭打(女)"],
  ["female_onahole", "飛機杯(女)"],
  ["female_body_swap", "變身術(女)"],
  ["female_lizard_girl", "蜥蜴娘(女)"],
  ["female_zombie", "僵屍(女)"],
  ["female_hairjob", "頭髮play(女)"],
  ["female_sunglasses", "太陽鏡(女)"],
  ["female_wooden_horse", "木馬(女)"],
  ["female_cbt", "jj調教(女)"],
  ["female_gender_bender", "掰彎(女)"],
  ["female_tailjob", "尾巴play(女)"],
  ["forniphilia", "家具play(女)"],
  ["female_mermaid", "美人魚(女)"],
  ["female_catfight", "戰♀鬥(女)"],
  ["female_glory_hole", "牆洞(女)"],
  ["female_smegma", "包皮垢(女)"],
  ["female_mouse_girl", "鼠娘(女)"],
  ["female_pantyjob", "內褲play(女)"],
  ["female_clamp", "夾子(女)"],
  ["female_nipple_expansion", "乳頭擴張(女)"],
  ["oldlady", "老女人(女)"],
  ["female_phimosis", "包莖(女)"],
  ["female_shared_senses", "共感(女)"],
  ["female_dougi", "武道服(女)"],
  ["female_wrestling", "角鬥(女)"],
  ["female_ear_fuck", "耳交(女)"],
  ["female_full_censorship", "全面審查(女)"],
  ["female_multiple_breasts", "多乳房(女)"],
  ["female_speculum", "擴陰器/鴨嘴器(女)"],
  ["female_plant_girl", "植物娘(女)"],
  ["frottage", "擊劍(女)"],
  ["female_mmf threesome", "二龍一鳳(女)"],
  ["female_syringe", "註射器(女)"],
  ["female_body_painting", "人體彩繪(女)"],
  ["female_fox", "狐狸(女)"],
  ["female_harpy", "鷹身女妖(女)"],
  ["omorashi", "漏尿(女)"],
  ["female_spider_girl", "蜘蛛娘(女)"],
  ["female_weight_gain", "發福(女)"],
  ["female_table_masturbation", "桌角自慰(女)"],
  ["female_pig_girl", "豬娘(女)"],
  ["female_insect_girl", "蟲娘(女)"],
  ["female_infantilism", "大嬰兒(女)"],
  ["kindergartenuniform", "幼兒園校服(女)"],
  ["female_multiple_penises", "多陰莖(女)"],
  ["female_human_pet", "美女犬/犬奴(女)"],
  ["female_dragon", "龍(女)"],
  ["female_raccoon_girl", "浣熊娘/狸娘(女)"],
  ["female_slug", "蛞蝓(女)"],
  ["female_cannibalism", "同類相食(女)"],
  ["female_phone_sex", "電話性愛(女)"],
  ["female_squid_girl", "烏賊娘(女)"],
  ["female_balls_expansion", "睾丸膨大(女)"],
  ["female_cashier", "收銀員/售貨員(女)"],
  ["female_dicknipples", "乳頭似jj(女)"],
  ["female_stretching", "拉伸(女)"],
  ["female_stewardess", "空姐(女)"],
  ["female_centaur", "半人馬(女)"],
  ["female_necrophilia", "冰戀(女)"],
  ["grandmother", "奶奶(女)"],
  ["female_growth", "巨大化(女)"],
  ["female_ponygirl", "馬具play(女)"],
  ["female_menstruation", "月經(女)"],
  ["female_legjob", "腿部play(女)"],
  ["female_sheep_girl", "綿羊娘(女)"],
  ["female_kneepit_sex", "膝窩play(女)"],
  ["female_octopus", "章魚(女)"],
  ["female_vacbed", "真空床/真空包裝(女)"],
  ["aliengirl", "女外星人(女)"],
  ["female_balljob", "睾丸play(女)"],
  ["female_butler", "執事|管家(女)"],
  ["granddaughter", "孫女(女)"],
  ["female_triple_vaginal", "三龍入穴(女)"],
  ["female_gasmask", "防毒面具(女)"],
  ["female_penis birth", "陰莖生殖(女)"],
  ["female_cockslapping", "用jj抽打(女)"],
  ["female_squirrel_girl", "松鼠娘(女)"],
  ["hijab", "頭巾(女)"],
  ["female_full_body_tattoo", "全身紋身(女)"],
  ["female_prehensile_hair", "操髮術(女)"],
  ["female_dog", "狗(女)"],
  ["female_forniphilia", "傢具play(女)"],
];

/** Paid comic tags from /filter?point=2; disabled entries are omitted. */
const relamanhuaMaleTags = [
  ["male_anal", "肛交(男)"],
  ["male_males_only", "全男性(男)"],
  ["male_tomgirl", "偽娘(男)"],
  ["male_crossdressing", "異裝癖/女裝大佬(男)"],
  ["male_nakadashi", "中出(男)"],
  ["male_sole_male", "單男主(男)"],
  ["male_shotacon", "正太控/正太(男)"],
  ["male_muscle", "肌肉(男)"],
  ["male_blowjob", "口交(男)"],
  ["male_stockings", "絲襪(男)"],
  ["male_schoolboy_uniform", "男學生制服(男)"],
  ["male_glasses", "眼鏡(男)"],
  ["male_bondage", "捆綁(男)"],
  ["male_huge_penis", "巨根(男)"],
  ["male_group", "群交(男)"],
  ["male_furry", "獸男/獸人(男)"],
  ["male_dark_skin", "黑皮(男)"],
  ["male_sex_toys", "情趣玩具(男)"],
  ["male_bbm", "肥男(男)"],
  ["male_ahegao", "高潮臉/啊嘿顏(男)"],
  ["male_dilf", "熟男(男)"],
  ["male_schoolgirl_uniform", "女學生制服(男)"],
  ["male_josou_seme", "女裝攻(男)"],
  ["male_collar", "項圈(男)"],
  ["male_kemonomimi", "獸耳(男)"],
  ["male_rape", "強暴(男)"],
  ["male_feminization", "女體化(男)"],
  ["male_handjob", "擼/拤(男)"],
  ["male_business_suit", "西裝(男)"],
  ["male_twintails", "雙馬尾(男)"],
  ["male_lingerie", "內衣(男)"],
  ["male_tentacles", "觸手(男)"],
  ["male_teacher", "教師(男)"],
  ["male_tutor", "調教(男)"],
  ["male_incest", "亂倫(男)"],
  ["male_military", "軍裝(男)"],
  ["male_condom", "避孕套(男)"],
  ["male_maid", "女僕(男)"],
  ["male_kimono", "和服(男)"],
  ["male_big_penis", "大根/大jj(男)"],
  ["male_catboy", "貓男(男)"],
  ["male_prostate_massage", "前列腺按摩(男)"],
  ["male_demon", "惡魔(男)"],
  ["male_gender_bender", "掰彎(男)"],
  ["male_mind_control", "催眠(男)"],
  ["male_exhibitionism", "暴露癖(男)"],
  ["male_brother", "兄弟(男)"],
  ["male_horns", "犄角(男)"],
  ["male_masturbation", "手淫(男)"],
  ["male_frottage", "擊劍/摩擦淫(男)"],
  ["male_blindfold", "蒙眼(男)"],
  ["male_unusual_pupils", "異瞳(男)"],
  ["male_bikini", "比基尼(男)"],
  ["male_prostitution", "賣淫/援交(男)"],
  ["male_drugs", "嗑藥(男)"],
  ["male_kissing", "親吻(男)"],
  ["male_swimsuit", "泳衣(男)"],
  ["male_piercing", "穿刺(男)"],
  ["male_elf", "精靈(男)"],
  ["male_cosplaying", "cosplay/角色扮演/cos(男)"],
  ["male_chastity_belt", "貞操帶(男)"],
  ["male_monster", "怪獸(男)"],
  ["male_mind_break", "意識崩壞(男)"],
  ["male garter belt", "吊襪帶(男)"],
  ["male_beauty_mark", "美人痣(男)"],
  ["male_old_man", "老男人(男)"],
  ["male_pantyhose", "褲襪(男)"],
  ["male_x_ray", "透視(男)"],
  ["male_netorare", "寢取/綠帽/NTR/牛頭人(男)"],
  ["male_rimjob", "舔肛/舔菊花(男)"],
  ["male_tanlines", "日曬痕(男)"],
  ["male_dog_boy", "狗男(男)"],
  ["male_tracksuit", "運動服(男)"],
  ["male_filming", "錄像(男)"],
  ["male_gag", "塞口球(男)"],
  ["male_urethra_insertion", "尿道插入(男)"],
  ["male_bear_boy", "熊男(男)"],
  ["male_footjob", "足交(男)"],
  ["male_fox_boy", "狐男(男)"],
  ["male_bald", "禿頭(男)"],
  ["male_human_on_furry", "人獸(男)"],
  ["male_slave", "奴隸(男)"],
  ["male_virginity", "童貞(男)"],
  ["male_apron", "圍裙(男)"],
  ["double_anal", "雙龍入菊(男)"],
  ["male_low_shotacon", "輕度正太控(男)"],
  ["male_blackmail", "脅迫(男)"],
  ["male_masked_face", "面具男(男)"],
  ["male_sweating", "汗流浹背(男)"],
  ["male_tail_plug", "假尾巴(男)"],
  ["male_bunny_boy", "兔郎(男)"],
  ["male_cheating", "偷情(男)"],
  ["male_gyaru_oh", "偽娘太妹(男)"],
  ["male_onahole", "飛機杯(男)"],
  ["male_policeman", "警察(男)"],
  ["male_sleeping", "入眠中/夢淫(男)"],
  ["male_urination", "放尿(男)"],
  ["male_dickgirl_on_male", "大屌萌妹乾漢子(男)"],
  ["male_tights", "緊身衣(男)"],
  ["male_wolf_boy", "狼男(男)"],
  ["male_beast", "野獸(男)"],
  ["male_latex", "緊身皮衣/膠衣(男)"],
  ["male_bride", "新娘(男)"],
  ["male_cbt", "jj調教(男)"],
  ["male_dragon", "龍(男)"],
  ["male_orc", "獸人(男)"],
  ["male_school_swimsuit", "死庫水/學校泳裝(男)"],
  ["male_father", "父(男)"],
  ["male_inseki", "無血緣亂倫(男)"],
  ["male_body_writing", "身上寫字(男)"],
  ["male_big_ass", "肥臀(男)"],
  ["male_double_penetration", "雙插入(男)"],
  ["male_fisting", "毆打(男)"],
  ["male_harem", "後宮(男)"],
  ["male_humiliation", "羞辱(男)"],
  ["male_thigh_high_boots", "長靴(男)"],
  ["male_public_use", "公眾便所/肉便器(男)"],
  ["male_pregnant", "懷孕(男)"],
  ["male_selfcest", "selfcest/自交(男)"],
  ["male_moral_degeneration", "墮落/背德(男)"],
  ["male_nurse", "護士(男)"],
  ["male_pegging", "逆肛交/pegging(男)"],
  ["male_drunk", "醉酒(男)"],
  ["male_eyepatch", "單眼罩/獨眼罩(男)"],
  ["male_big_breasts", "大胸(男)"],
  ["male_chikan", "癡漢(男)"],
  ["male_chinese_dress", "旗袍(男)"],
  ["male_inflation", "肚子膨大(男)"],
  ["male_orgasm_denial", "拒絕高潮(男)"],
  ["male_scar", "疤痕(男)"],
  ["male_stomach_deformation", "一步到胃(男)"],
  ["male_angel", "天使(男)"],
  ["male_bloomers", "燈籠褲(男)"],
  ["male_corruption", "黑化(男)"],
  ["male_foot_licking", "戀足/舔腳(男)"],
  ["male_hairy", "陰毛濃郁(男)"],
  ["male_leotard", "緊身褲(男)"],
  ["male_ninja", "忍者(男)"],
  ["male_ryona", "ryona/殘虐快感(男)"],
  ["male_solo_action", "自慰表演(男)"],
  ["male_twins", "雙胞胎(男)"],
  ["male_bisexual", "雙性戀(男)"],
  ["male_blood", "血腥(男)"],
  ["male_coach", "教練(男)"],
  ["male_lizard_guy", "蜥蜴人(男)"],
  ["male_miko", "巫女(男)"],
  ["male_smell", "臭(男)"],
  ["male_asphyxiation", "窒息(男)"],
  ["male_breast_expansion", "乳房擴張(男)"],
  ["male_cowman", "奶牛裝(男)"],
  ["male_lactation", "乳汁(男)"],
  ["maweinan", "馬尾(男)"],
  ["male_miniguy", "一寸法師(男)"],
  ["male_pig_man", "豬男(男)"],
  ["male_phimosis", "包莖(男)"],
  ["male_shibari", "捆綁(日式)(男)"],
  ["male_scat", "脫糞/排便(男)"],
  ["male_vampire", "吸血鬼(男)"],
  ["male_anal_birth", "肛門生產(男)"],
  ["male_bukkake", "精子風呂/精液浴(男)"],
  ["male_eyemask", "眼罩(男)"],
  ["male_gymshorts", "運動短褲(男)"],
  ["male_nose_hook", "鼻鉤(男)"],
  ["male_snuff", "虐殺(男)"],
  ["male_sumata", "素股/蹭蹭不進去(男)"],
  ["male_unusual_teeth", "特殊牙齒/尖牙(男)"],
  ["male_body_modification", "肉體改造(男)"],
  ["male_dog", "狗(男)"],
  ["male_enema", "灌腸(男)"],
  ["male_oni", "鬼(男)"],
  ["male_smegma", "包皮垢(男)"],
  ["male_shrinking", "縮小(男)"],
  ["male_slime", "史萊姆(男)"],
  ["male_tall_man", "男孩身材較高(男)"],
  ["male_transformation", "變形(男)"],
  ["male_bdsm", "sm捆綁(男)"],
  ["male_christmas", "聖誕裝(男)"],
  ["male_freckles", "雀斑(男)"],
  ["male_giant", "巨人(男)"],
  ["male_gyaru", "辣妹(男)"],
  ["male_torture", "調教(男)"],
  ["male_voyeurism", "偷窺(男)"],
  ["male_wormhole", "蟲洞/空間轉移(男)"],
  ["male_amputee", "截肢(男)"],
  ["male_autofellatio", "自口交(男)"],
  ["male_clothed_female_nude_male", "女性著衣男性赤裸(男)"],
  ["male_diaper", "尿布(男)"],
  ["male_guro", "糞/血腥獵奇(男)"],
  ["male_goblin", "哥布林/地精(男)"],
  ["male_robot", "機器人(男)"],
  ["male_bodysuit", "連身衣(男)"],
  ["male_butler", "執事/管家(男)"],
  ["male_body_swap", "變身術(男)"],
  ["male_chloroform", "麻醉(男)"],
  ["male_double_blowjob", "雙人口交/雙人侍奉(男)"],
  ["male_fundoshi", "兜襠布(男)"],
  ["male_first_person_perspective", "第一人稱視角(男)"],
  ["male_horse_boy", "馬男(男)"],
  ["lactation", "乳汁(男)"],
  ["male_living_clothes", "活化衣服(男)"],
  ["male_paizuri", "乳交(男)"],
  ["male_pasties", "乳貼(男)"],
  ["male_priest", "牧師/祭司(男)"],
  ["male_armpit_licking", "舔腋窩(男)"],
  ["male_age_regression", "返老還童(男)"],
  ["male_animal_on_animal", "動物vs動物(男)"],
  ["male_bandages", "繃帶(男)"],
  ["male_dark_sclera", "黑色眼白(男)"],
  ["male_electric_shocks", "電擊(男)"],
  ["male_facesitting", "坐臉(男)"],
  ["male_hairy_armpits", "腋窩有毛(男)"],
  ["male_infantilism", "大嬰兒(男)"],
  ["male_long_tongue", "長舌(男)"],
  ["male_minotaur", "米諾陶/牛頭怪/NTR(男)"],
  ["male_raccoon_boy", "浣熊男/狸男(男)"],
  ["male_sunglasses", "太陽鏡(男)"],
  ["male_alien", "異形(男)"],
  ["breastfeeding", "餵奶(男)"],
  ["male_ball_sucking", "吸吮睾丸(男)"],
  ["male_coprophagia", "食糞/黃金(男)"],
  ["male_fairy", "妖精(男)"],
  ["male_glory_hole", "牆洞(男)"],
  ["male_human_pet", "犬奴(男)"],
  ["male_merman", "魚人/雄性人魚(男)"],
  ["male_piss_drinking", "飲尿(男)"],
  ["male_parasite", "寄生(男)"],
  ["male_ssbbm", "身高八尺腰圍也是八尺的男人(男)"],
  ["male_tiara", "頭冠(男)"],
  ["male_unicorn", "獨角獸(男)"],
  ["male_waitress", "女僕(男)"],
  ["yisheng", "醫生(男)"],
  ["male_cousin", "表哥表弟(男)"],
  ["male_full_body_tattoo", "全身紋身(男)"],
  ["male_gijinka", "擬人化(男)"],
  ["male_horse_cock", "馬弔(男)"],
  ["male_kunoichi", "女忍者(男)"],
  ["male_kigurumi", "玩偶裝(男)"],
  ["male_layer_cake", "夾心蛋糕/兩鮑夾一棍(男)"],
  ["male_metal_armor", "盔甲/鎧甲(男)"],
  ["male_machine", "性愛機器(男)"],
  ["male_multiple_penises", "多陰莖(男)"],
  ["male_prolapse", "脫垂/脫肛/宮脫(男)"],
  ["male_shaved_head", "剃光頭(男)"],
  ["male_shark_boy", "鯊魚男(男)"],
  ["male_skinsuit", "畫皮(男)"],
  ["male_unbirth", "胎兒(男)"],
  ["male_vore", "vore/丸吞(男)"],
  ["male_vomit", "嘔吐(男)"],
  ["male_wrestling", "角鬥(男)"],
];

/**
 * Catalogue sort aliases. The host splits each option entry on the first dash
 * into value and label, so a value must never contain a dash and the raw
 * ordering strings are mapped back here.
 */
/** @type {Record<string, string>} */
const relamanhuaOrderings = {
  updated: "-datetime_updated",
  popular: "-popular",
  oldest: "datetime_updated",
};
/** Ranking rails on /api/v3/ranks: [value, type, date_type, label]. */
const relamanhuaRankOptions = [
  ["1d", "1", "day", "免費日榜"],
  ["1w", "1", "week", "免費週榜"],
  ["1m", "1", "month", "免費月榜"],
  ["1t", "1", "total", "免費總榜"],
  ["2d", "2", "day", "付費日榜"],
  ["2w", "2", "week", "付費週榜"],
  ["2m", "2", "month", "付費月榜"],
  ["2t", "2", "total", "付費總榜"],
];
const relamanhuaFavoritePageSize = 30;
const relamanhuaCommentPageSize = 10;

// AES-128 S-box and its inverse (FIPS 197), 256 bytes each as hex.
const relamanhuaSboxHex =
  "637c777bf26b6fc53001672bfed7ab76ca82c97dfa5947f0add4a2af9ca472c0" +
  "b7fd9326363ff7cc34a5e5f171d8311504c723c31896059a071280e2eb27b275" +
  "09832c1a1b6e5aa0523bd6b329e32f8453d100ed20fcb15b6acbbe394a4c58cf" +
  "d0efaafb434d338545f9027f503c9fa851a3408f929d38f5bcb6da2110fff3d2" +
  "cd0c13ec5f974417c4a77e3d645d197360814fdc222a908846eeb814de5e0bdb" +
  "e0323a0a4906245cc2d3ac629195e479e7c8376d8dd54ea96c56f4ea657aae08" +
  "ba78252e1ca6b4c6e8dd741f4bbd8b8a703eb5664803f60e613557b986c11d9e" +
  "e1f8981169d98e949b1e87e9ce5528df8ca1890dbfe6426841992d0fb054bb16";
const relamanhuaInvSboxHex =
  "52096ad53036a538bf40a39e81f3d7fb7ce339829b2fff87348e4344c4dee9cb" +
  "547b9432a6c2233dee4c950b42fac34e082ea16628d924b2765ba2496d8bd125" +
  "72f8f66486689816d4a45ccc5d65b6926c704850fdedb9da5e154657a78d9d84" +
  "90d8ab008cbcd30af7e45805b8b34506d02c1e8fca3f0f02c1afbd0301138a6b" +
  "3a9111414f67dcea97f2cfcef0b4e67396ac7422e7ad3585e2f937e81c75df6e" +
  "47f11a711d29c5896fb7620eaa18be1bfc563e4bc6d279209adbc0fe78cd5af4" +
  "1fdda8338807c731b11210592780ec5f60517fa919b54a0d2de57a9f93c99cef" +
  "a0e03b4dae2af5b0c8ebbb3c83539961172b047eba77d626e169146355210c7d";

/** @type {Uint8Array | null} */
let relamanhuaSboxCache = null;
/** @type {Uint8Array | null} */
let relamanhuaInvSboxCache = null;

/**
 * @param {string} hex
 * @returns {Uint8Array}
 */
function relamanhuaHexToBytes(hex) {
  const clean = hex.replace(/\s+/g, "");
  const length = clean.length >> 1;
  const bytes = new Uint8Array(length);
  for (let i = 0; i < length; i++) {
    const value = parseInt(clean.substring(i * 2, i * 2 + 2), 16);
    if (value !== value) throw new Error("十六进制数据无效");
    bytes[i] = value;
  }
  return bytes;
}

/**
 * @param {string} text
 * @returns {Uint8Array}
 */
function relamanhuaUtf8Encode(text) {
  /** @type {number[]} */
  const out = [];
  for (let i = 0; i < text.length; i++) {
    let code = text.charCodeAt(i);
    if (code >= 0xd800 && code <= 0xdbff && i + 1 < text.length) {
      const low = text.charCodeAt(i + 1);
      if (low >= 0xdc00 && low <= 0xdfff) {
        code = 0x10000 + ((code - 0xd800) << 10) + (low - 0xdc00);
        i++;
      }
    }
    if (code < 0x80) {
      out.push(code);
    } else if (code < 0x800) {
      out.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
    } else if (code < 0x10000) {
      out.push(
        0xe0 | (code >> 12),
        0x80 | ((code >> 6) & 0x3f),
        0x80 | (code & 0x3f),
      );
    } else {
      out.push(
        0xf0 | (code >> 18),
        0x80 | ((code >> 12) & 0x3f),
        0x80 | ((code >> 6) & 0x3f),
        0x80 | (code & 0x3f),
      );
    }
  }
  return new Uint8Array(out);
}

/**
 * @param {Uint8Array} bytes
 * @returns {string}
 */
function relamanhuaUtf8Decode(bytes) {
  let out = "";
  let i = 0;
  while (i < bytes.length) {
    const first = bytes[i++];
    let code;
    if (first < 0x80) {
      code = first;
    } else if ((first & 0xe0) === 0xc0) {
      code = ((first & 0x1f) << 6) | (bytes[i++] & 0x3f);
    } else if ((first & 0xf0) === 0xe0) {
      code =
        ((first & 0x0f) << 12) |
        ((bytes[i++] & 0x3f) << 6) |
        (bytes[i++] & 0x3f);
    } else {
      code =
        ((first & 0x07) << 18) |
        ((bytes[i++] & 0x3f) << 12) |
        ((bytes[i++] & 0x3f) << 6) |
        (bytes[i++] & 0x3f);
    }
    if (code > 0xffff) {
      const point = code - 0x10000;
      out += String.fromCharCode(
        0xd800 + (point >> 10),
        0xdc00 + (point & 0x3ff),
      );
    } else {
      out += String.fromCharCode(code);
    }
  }
  return out;
}

/**
 * @returns {Uint8Array}
 */
function relamanhuaSbox() {
  if (relamanhuaSboxCache === null)
    relamanhuaSboxCache = relamanhuaHexToBytes(relamanhuaSboxHex);
  return relamanhuaSboxCache;
}

/**
 * @returns {Uint8Array}
 */
function relamanhuaInvSbox() {
  if (relamanhuaInvSboxCache === null)
    relamanhuaInvSboxCache = relamanhuaHexToBytes(relamanhuaInvSboxHex);
  return relamanhuaInvSboxCache;
}

/**
 * @param {number} value
 * @returns {number}
 */
function relamanhuaXtime(value) {
  return ((value << 1) ^ ((value & 0x80) !== 0 ? 0x1b : 0)) & 0xff;
}

/**
 * @param {number} left
 * @param {number} right
 * @returns {number}
 */
function relamanhuaGmul(left, right) {
  let a = left & 0xff;
  let b = right & 0xff;
  let result = 0;
  for (let i = 0; i < 8; i++) {
    if ((b & 1) !== 0) result ^= a;
    const high = a & 0x80;
    a = (a << 1) & 0xff;
    if (high !== 0) a ^= 0x1b;
    b >>= 1;
  }
  return result & 0xff;
}

/**
 * @param {Uint8Array} key 16-byte AES-128 key.
 * @returns {Uint8Array} 176 bytes: 11 round keys.
 */
function relamanhuaExpandKey(key) {
  const sbox = relamanhuaSbox();
  const words = new Uint8Array(176);
  words.set(key, 0);
  let rcon = 1;
  for (let index = 16; index < 176; index += 4) {
    const a0 = words[index - 4];
    const a1 = words[index - 3];
    const a2 = words[index - 2];
    const a3 = words[index - 1];
    if (index % 16 === 0) {
      words[index] = words[index - 16] ^ sbox[a1] ^ rcon;
      words[index + 1] = words[index - 15] ^ sbox[a2];
      words[index + 2] = words[index - 14] ^ sbox[a3];
      words[index + 3] = words[index - 13] ^ sbox[a0];
      rcon = relamanhuaXtime(rcon);
    } else {
      words[index] = words[index - 16] ^ a0;
      words[index + 1] = words[index - 15] ^ a1;
      words[index + 2] = words[index - 14] ^ a2;
      words[index + 3] = words[index - 13] ^ a3;
    }
  }
  return words;
}

/**
 * @param {Uint8Array} state
 * @returns {void}
 */
function relamanhuaInvShiftRows(state) {
  let temp = state[13];
  state[13] = state[9];
  state[9] = state[5];
  state[5] = state[1];
  state[1] = temp;

  temp = state[2];
  state[2] = state[10];
  state[10] = temp;
  temp = state[6];
  state[6] = state[14];
  state[14] = temp;

  temp = state[3];
  state[3] = state[7];
  state[7] = state[11];
  state[11] = state[15];
  state[15] = temp;
}

// Cache the four finite-field products once. Computing each product bit by bit
// for every block exceeds QuickJS's 5-second limit on full chapter lists.
const relamanhuaInvMixTables = [9, 11, 13, 14].map((coefficient) =>
  Uint8Array.from({ length: 256 }, (_, value) =>
    relamanhuaGmul(value, coefficient),
  ),
);

/**
 * @param {Uint8Array} state
 * @returns {void}
 */
function relamanhuaInvMixColumns(state) {
  const [mul9, mul11, mul13, mul14] = relamanhuaInvMixTables;
  for (let column = 0; column < 4; column++) {
    const base = column * 4;
    const a0 = state[base];
    const a1 = state[base + 1];
    const a2 = state[base + 2];
    const a3 = state[base + 3];
    state[base] = mul14[a0] ^ mul11[a1] ^ mul13[a2] ^ mul9[a3];
    state[base + 1] = mul9[a0] ^ mul14[a1] ^ mul11[a2] ^ mul13[a3];
    state[base + 2] = mul13[a0] ^ mul9[a1] ^ mul14[a2] ^ mul11[a3];
    state[base + 3] = mul11[a0] ^ mul13[a1] ^ mul9[a2] ^ mul14[a3];
  }
}

/**
 * @param {Uint8Array} input
 * @param {number} offset
 * @param {Uint8Array} words
 * @returns {Uint8Array}
 */
function relamanhuaDecryptBlock(input, offset, words) {
  const invSbox = relamanhuaInvSbox();
  const state = new Uint8Array(16);
  for (let i = 0; i < 16; i++) state[i] = input[offset + i] ^ words[160 + i];
  for (let round = 9; round >= 1; round--) {
    relamanhuaInvShiftRows(state);
    for (let i = 0; i < 16; i++) state[i] = invSbox[state[i]];
    const base = round * 16;
    for (let i = 0; i < 16; i++) state[i] ^= words[base + i];
    relamanhuaInvMixColumns(state);
  }
  relamanhuaInvShiftRows(state);
  for (let i = 0; i < 16; i++) state[i] = invSbox[state[i]];
  for (let i = 0; i < 16; i++) state[i] ^= words[i];
  return state;
}

/**
 * @param {Uint8Array} key 16-byte key.
 * @param {Uint8Array} iv 16-byte IV.
 * @param {Uint8Array} data Ciphertext, a multiple of 16 bytes.
 * @returns {Uint8Array} Plaintext with PKCS#7 padding removed.
 */
function relamanhuaAes128CbcDecrypt(key, iv, data) {
  if (key.length !== 16)
    throw new Error("AES 密钥长度不是 16 字节：" + key.length);
  if (iv.length !== 16)
    throw new Error("AES IV 长度不是 16 字节：" + iv.length);
  if (data.length === 0 || data.length % 16 !== 0)
    throw new Error("密文长度无效：" + data.length);
  const words = relamanhuaExpandKey(key);
  const output = new Uint8Array(data.length);
  /** @type {Uint8Array} */
  let previous = iv;
  for (let offset = 0; offset < data.length; offset += 16) {
    const block = relamanhuaDecryptBlock(data, offset, words);
    for (let i = 0; i < 16; i++) output[offset + i] = block[i] ^ previous[i];
    previous = data.subarray(offset, offset + 16);
  }
  const pad = output[output.length - 1];
  if (pad < 1 || pad > 16 || pad > output.length)
    throw new Error("PKCS#7 填充无效");
  for (let i = output.length - pad; i < output.length; i++) {
    if (output[i] !== pad) throw new Error("PKCS#7 填充校验失败");
  }
  return output.subarray(0, output.length - pad);
}

/**
 * @param {unknown} error
 * @returns {string}
 */
function relamanhuaErrorText(error) {
  return error instanceof Error ? error.message : String(error);
}

/**
 * @param {unknown} value
 * @returns {string}
 */
function relamanhuaText(value) {
  if (value === null || value === undefined) return "";
  return String(value).replace(/\s+/g, " ").trim();
}

/**
 * @param {string} blob `iv(16 chars) + hex(ciphertext)`.
 * @param {string} keyText AES key as text.
 * @returns {string}
 */
function relamanhuaDecryptBlob(blob, keyText) {
  if (typeof blob !== "string" || blob.length <= 16)
    throw new Error("加密数据长度无效");
  const key = relamanhuaUtf8Encode(keyText);
  const iv = relamanhuaUtf8Encode(blob.substring(0, 16));
  const data = relamanhuaHexToBytes(blob.substring(16));
  return relamanhuaUtf8Decode(relamanhuaAes128CbcDecrypt(key, iv, data));
}

/**
 * @param {string} html
 * @param {string} name
 * @returns {string}
 */
function relamanhuaPageVariable(html, name) {
  const match = new RegExp("var\\s+" + name + "\\s*=\\s*'([^']*)'").exec(html);
  return match ? match[1] : "";
}

/**
 * @returns {string}
 */
function relamanhuaBase() {
  const configured = Hazuki.settings.get("baseUrl");
  const value = typeof configured === "string" ? configured.trim() : "";
  return (value || relamanhuaOrigin).replace(/\/+$/, "");
}

/**
 * @param {string} accept
 * @returns {Record<string, string>}
 */
function relamanhuaHeaders(accept) {
  /** @type {Record<string, string>} */
  const headers = {
    "User-Agent": relamanhuaUserAgent,
    "Accept-Language": "zh-CN,zh;q=0.9",
  };
  if (accept) headers.Accept = accept;
  return headers;
}

/**
 * Reads carry the session when one exists. The site decides entitlement per
 * account: without the token even a signed-in reader is treated as a guest and
 * paid titles stop at the 5 page trial (`results.is_lock`).
 * @param {string} path
 * @param {string} accept
 * @returns {Promise<string>}
 */
async function relamanhuaGet(path, accept) {
  const token = relamanhuaToken();
  let response = await Hazuki.http.get(
    relamanhuaBase() + path,
    relamanhuaAuthHeaders(token, accept),
  );
  if (token && (response.status === 401 || response.status === 403)) {
    // A stale stored token must not break pages that work anonymously.
    response = await Hazuki.http.get(
      relamanhuaBase() + path,
      relamanhuaHeaders(accept),
    );
  }
  if (response.status !== 200)
    throw new Error("请求失败（HTTP " + response.status + "）：" + path);
  return response.body;
}

/**
 * @param {string} url
 * @returns {string}
 */
function relamanhuaAbsolute(url) {
  const value = relamanhuaText(url);
  if (!value) return "";
  if (/^https?:\/\//i.test(value)) return value;
  if (value.indexOf("//") === 0) return "https:" + value;
  if (value.charAt(0) === "/") return relamanhuaBase() + value;
  return relamanhuaBase() + "/" + value;
}

/**
 * @param {any} value
 * @returns {string[]}
 */
function relamanhuaNameList(value) {
  if (!Array.isArray(value)) return [];
  /** @type {string[]} */
  const out = [];
  for (const entry of value) {
    if (typeof entry === "string") {
      if (relamanhuaText(entry)) out.push(relamanhuaText(entry));
    } else if (
      entry &&
      typeof entry.name === "string" &&
      relamanhuaText(entry.name)
    ) {
      out.push(relamanhuaText(entry.name));
    }
  }
  return out;
}

/**
 * @param {HtmlElement} row
 * @returns {string[]}
 */
function relamanhuaRowLinks(row) {
  /** @type {string[]} */
  const out = [];
  for (const anchor of row.querySelectorAll("a")) {
    const text = relamanhuaText(anchor.text).replace(/^#/, "");
    if (text) out.push(text);
  }
  return out;
}

/**
 * @param {string} label
 * @param {string[]} candidates
 * @returns {boolean}
 */
function relamanhuaLabelMatches(label, candidates) {
  for (const candidate of candidates) {
    if (label === candidate) return true;
  }
  return false;
}

/**
 * Parse the server-rendered comic page. The site serves both Traditional and
 * Simplified labels, so both spellings are accepted for every field.
 * @param {HtmlDocument} doc
 * @param {string} pathWord
 * @returns {SourceComicDetails}
 */
function relamanhuaParseDetail(doc, pathWord) {
  const coverNode = doc.querySelector(".comicParticulars-left-img img");
  const titleNode = doc.querySelector(".comicParticulars-title-right h6");
  /** @type {string[]} */
  const aliases = [];
  /** @type {string[]} */
  const authors = [];
  /** @type {string[]} */
  const themes = [];
  /** @type {string[]} */
  const tags = [];
  /** @type {string[]} */
  const statuses = [];
  let updateTime = "";
  for (const row of doc.querySelectorAll(".comicParticulars-title-right li")) {
    const labelNode = row.querySelector("span");
    if (!labelNode) continue;
    const label = relamanhuaText(labelNode.text).replace(/[：:]\s*$/, "");
    if (!label) continue;
    const valueNode = row.querySelector(".comicParticulars-right-txt");
    const value = valueNode ? relamanhuaText(valueNode.text) : "";
    if (relamanhuaLabelMatches(label, ["别名", "別名"])) {
      for (const part of value.split(/[,，]/)) {
        const item = relamanhuaText(part);
        if (item && item !== "---") aliases.push(item);
      }
    } else if (relamanhuaLabelMatches(label, ["作者"])) {
      for (const name of relamanhuaRowLinks(row)) authors.push(name);
    } else if (relamanhuaLabelMatches(label, ["最后更新", "最後更新"])) {
      updateTime = value;
    } else if (relamanhuaLabelMatches(label, ["状态", "狀態"])) {
      if (value && value !== "---") statuses.push(value);
    } else if (relamanhuaLabelMatches(label, ["题材", "題材"])) {
      for (const name of relamanhuaRowLinks(row)) themes.push(name);
    } else if (relamanhuaLabelMatches(label, ["标签", "標籤"])) {
      for (const name of relamanhuaRowLinks(row)) tags.push(name);
    }
  }
  const introNode =
    doc.querySelector(".comicParticulars-synopsis .intro") ||
    doc.querySelector(".comicParticulars-synopsis p");
  /** @type {Record<string, string[]>} */
  const groups = {};
  if (authors.length) groups["作者"] = authors;
  if (themes.length) groups["题材"] = themes;
  if (tags.length) groups["标签"] = tags;
  if (aliases.length) groups["别名"] = aliases;
  groups["状态"] = statuses;
  /** @type {SourceComicDetails} */
  const details = {
    id: pathWord,
    title:
      titleNode && relamanhuaText(titleNode.text)
        ? relamanhuaText(titleNode.text)
        : pathWord,
    cover: coverNode ? relamanhuaAbsolute(coverNode.attributes.src) : "",
    chapters: {},
    headerStats: [{ text: statuses.join(" · ") }],
    tags: groups,
    infoFields: [
      {
        label: { zh: "作者", en: "Author" },
        values: authors,
        action: "search",
      },
      { label: { zh: "题材", en: "Themes" }, values: themes, action: "search" },
      { label: { zh: "标签", en: "Tags" }, values: tags, action: "search" },
      { label: { zh: "别名", en: "Aliases" }, values: aliases, action: "copy" },
      { label: { zh: "状态", en: "Status" }, values: statuses },
    ],
  };
  if (introNode) {
    const description = relamanhuaText(introNode.text);
    if (description) details.description = description;
  }
  if (updateTime) details.updateTime = updateTime;
  return details;
}

/**
 * @param {string} pathWord
 * @param {string} disposable Page-provided AES key text.
 * @returns {Promise<Record<string, string>>} Chapter id to display title.
 */
async function relamanhuaLoadChapters(pathWord, disposable) {
  const body = await relamanhuaGet(
    "/comicdetail/" + encodeURIComponent(pathWord) + "/chapters",
    "application/json",
  );
  /** @type {any} */
  let payload;
  try {
    payload = JSON.parse(body);
  } catch (error) {
    throw new Error("章节接口返回的不是 JSON");
  }
  if (!payload || payload.code !== 200 || typeof payload.results !== "string") {
    throw new Error(
      "章节接口返回异常：" + relamanhuaText(payload && payload.message),
    );
  }
  /** @type {any} */
  let decrypted;
  try {
    decrypted = JSON.parse(relamanhuaDecryptBlob(payload.results, disposable));
  } catch (error) {
    throw new Error("章节数据解密失败：" + relamanhuaErrorText(error));
  }
  const groups = decrypted && decrypted.groups ? decrypted.groups : {};
  /** @type {Record<string, string>} */
  const chapters = {};
  for (const groupKey of Object.keys(groups)) {
    const group = groups[groupKey];
    if (!group || !Array.isArray(group.chapters)) continue;
    const groupName = groupKey === "default" ? "" : relamanhuaText(group.name);
    for (const chapter of group.chapters) {
      if (!chapter || typeof chapter.id !== "string" || !chapter.id) continue;
      const name = relamanhuaText(chapter.name) || chapter.id;
      chapters[chapter.id] = groupName ? groupName + " · " + name : name;
    }
  }
  if (Object.keys(chapters).length === 0) throw new Error("没有解析到任何章节");
  return chapters;
}

/**
 * @param {any} item
 * @returns {SourceComic}
 */
function relamanhuaComicFromSearch(item) {
  const pathWord = relamanhuaText(item && item.path_word);
  /** @type {SourceComic} */
  const comic = {
    id: pathWord,
    title: relamanhuaText(item && item.name) || pathWord,
    cover: relamanhuaAbsolute(item && item.cover),
  };
  const themes = relamanhuaNameList(item && item.theme);
  if (themes.length) comic.tags = themes;
  return comic;
}

/**
 * @returns {string}
 */
function relamanhuaImageQuality() {
  return String(Hazuki.settings.get("imageQuality") || "") === "webp"
    ? "webp"
    : "jpg";
}

/**
 * The CDN serves a fixed 1500px render in either JPEG or WebP.
 * @param {string} url
 * @param {string} quality
 * @returns {string}
 */
function relamanhuaApplyQuality(url, quality) {
  if (quality !== "webp") return url;
  return url.replace(/\.h1500x\.jpg$/i, ".h1500x.webp");
}

/**
 * Standard Base64 of a UTF-8 string. The login payload sends
 * Base64(password + "-" + salt), so this has to match the site's encoder.
 * @param {string} text
 * @returns {string}
 */
function relamanhuaBase64Encode(text) {
  const alphabet =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  const bytes = relamanhuaUtf8Encode(text);
  let out = "";
  for (let i = 0; i < bytes.length; i += 3) {
    const b0 = bytes[i];
    const b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
    const b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
    out += alphabet.charAt(b0 >> 2);
    out += alphabet.charAt(((b0 & 3) << 4) | (b1 >> 4));
    out +=
      i + 1 < bytes.length
        ? alphabet.charAt(((b1 & 15) << 2) | (b2 >> 6))
        : "=";
    out += i + 2 < bytes.length ? alphabet.charAt(b2 & 63) : "=";
  }
  return out;
}

/**
 * @param {unknown} value
 * @returns {string}
 */
function relamanhuaStripTags(value) {
  return relamanhuaText(
    String(value === null || value === undefined ? "" : value)
      .replace(/<[^>]*>/g, " ")
      .replace(/&nbsp;/g, " "),
  );
}

/**
 * @param {string} tag
 * @param {string} name
 * @returns {string}
 */
function relamanhuaTagAttribute(tag, name) {
  const match = new RegExp(name + '\\s*=\\s*"([^"]*)"').exec(tag);
  return match ? match[1] : "";
}

/**
 * Cards keep the real cover in data-src (lazyload) and may leave src empty.
 * @param {string} tag
 * @returns {string}
 */
function relamanhuaImageFromTag(tag) {
  return (
    relamanhuaTagAttribute(tag, "data-src") ||
    relamanhuaTagAttribute(tag, "src")
  );
}

/**
 * @param {string} chunk
 * @returns {string}
 */
function relamanhuaFirstImage(chunk) {
  const match = /<img\b[^>]*>/.exec(chunk);
  return match ? relamanhuaImageFromTag(match[0]) : "";
}

/**
 * @param {string} href
 * @returns {string}
 */
function relamanhuaComicIdFromHref(href) {
  const match = /\/comic\/([^"?#/]+)/.exec(relamanhuaText(href));
  return match ? match[1] : "";
}

/**
 * Title of a card as raw HTML: the <p> title attribute, its text, the image
 * alt, then any anchor text. Returns "" when a block carries a cover but no
 * title of its own, so callers can drop it.
 * @param {string} chunk
 * @returns {string}
 */
function relamanhuaCardTitle(chunk) {
  const paragraphTag = /<p\b[^>]*>/.exec(chunk);
  if (paragraphTag) {
    const fromTitle = relamanhuaStripTags(
      relamanhuaTagAttribute(paragraphTag[0], "title"),
    );
    if (fromTitle) return fromTitle;
    const paragraphBody = /<p\b[^>]*>([\s\S]*?)<\/p>/.exec(chunk);
    if (paragraphBody) {
      const text = relamanhuaStripTags(paragraphBody[1]);
      if (text) return text;
    }
  }
  const imageTag = /<img\b[^>]*>/.exec(chunk);
  if (imageTag) {
    const alt = relamanhuaStripTags(relamanhuaTagAttribute(imageTag[0], "alt"));
    if (alt) return alt;
  }
  const anchorBody = /<a\b[^>]*>([\s\S]*?)<\/a>/.exec(chunk);
  if (anchorBody) {
    const text = relamanhuaStripTags(anchorBody[1]);
    if (text) return text;
  }
  return "";
}

/**
 * Same rule as relamanhuaCardTitle but for an already parsed element.
 * @param {HtmlElement} node
 * @returns {string}
 */
function relamanhuaNodeTitle(node) {
  const paragraph = node.querySelector("p");
  if (paragraph) {
    const fromTitle = relamanhuaText(paragraph.attributes.title);
    if (fromTitle) return fromTitle;
    const fromText = relamanhuaStripTags(paragraph.text);
    if (fromText) return fromText;
  }
  const image = node.querySelector("img");
  if (image) {
    const alt = relamanhuaStripTags(image.attributes.alt);
    if (alt) return alt;
  }
  const anchor = node.querySelector("a");
  if (anchor) {
    const fromAnchor = relamanhuaStripTags(anchor.text);
    if (fromAnchor) return fromAnchor;
  }
  return "";
}

/**
 * Section headings carry inline <font> decoration and a trailing count such as
 * "付費漫畫（最近七天已更新326部）". Strip the tags without inserting spaces and
 * cut the count so the tab reads "付費漫畫".
 * @param {string} html
 * @returns {string}
 */
function relamanhuaSectionTitle(html) {
  const text = String(html === null || html === undefined ? "" : html)
    .replace(/<[^>]*>/g, "")
    .replace(/&nbsp;/g, " ");
  const cut = text.search(/[（(]/);
  return relamanhuaText(cut === -1 ? text : text.substring(0, cut));
}

/**
 * Split the homepage into its titled sections. Cards without a cover (the
 * update feed, the anime rails, and ranking rows whose cover sits in a sibling
 * node) drop out here, so only real cover-bearing comic rails remain.
 * @param {string} html
 * @returns {SourceExploreSection[]}
 */
function relamanhuaHomeSections(html) {
  const marks = [
    ...html.matchAll(
      /<h4 class="index-all-icon-left-txt">([\s\S]{0,200}?)<\/h4>/g,
    ),
  ];
  /** @type {SourceExploreSection[]} */
  const sections = [];
  for (let index = 0; index < marks.length; index++) {
    const start = marks[index].index;
    const end = index + 1 < marks.length ? marks[index + 1].index : html.length;
    const chunk = html.slice(start, end);
    const title = relamanhuaSectionTitle(marks[index][1]);
    if (!title) continue;
    /** @type {SourceComic[]} */
    const comics = [];
    for (const match of chunk.matchAll(
      /<a\b[^>]*href="\/comic\/([^"?#]+)"[^>]*>([\s\S]*?)<\/a>/g,
    )) {
      const cover = relamanhuaAbsolute(relamanhuaFirstImage(match[2]));
      if (!cover) continue;
      const name = relamanhuaCardTitle(match[2]);
      if (!name) continue;
      comics.push({ id: match[1], title: name, cover });
    }
    if (comics.length > 0) {
      /** @type {SourceExploreSection} */
      const section = { title, comics };
      if (title === "漫畫推薦") {
        section.viewMore = "category:" + title + "@recommend";
      } else if (title === "付費漫畫") {
        section.viewMore = "category:" + title + "@2";
      }
      sections.push(section);
    }
  }
  return sections;
}

/**
 * One section per ranking tab on /rank. Cartoon tabs hold no /comic links and
 * therefore produce no section.
 * @param {HtmlDocument} doc
 * @returns {SourceExploreSection[]}
 */
function relamanhuaRankSections(doc) {
  /** @type {Record<string, SourceComic[]>} */
  const byTab = {};
  for (const pane of doc.querySelectorAll(".tab-pane")) {
    const tabId = relamanhuaText(pane.attributes.id);
    if (!tabId) continue;
    /** @type {SourceComic[]} */
    const comics = [];
    for (const unit of pane.querySelectorAll(".ranking-allItem")) {
      const anchor = unit.querySelector("a");
      const image = unit.querySelector("img");
      if (!anchor || !image) continue;
      const id = relamanhuaComicIdFromHref(anchor.attributes.href);
      const cover = relamanhuaAbsolute(
        relamanhuaText(image.attributes["data-src"]) ||
          relamanhuaText(image.attributes.src),
      );
      const title = relamanhuaNodeTitle(unit);
      if (!id || !cover || !title) continue;
      comics.push({ id, title, cover });
    }
    if (comics.length > 0) byTab[tabId] = comics;
  }
  /** @type {SourceExploreSection[]} */
  const sections = [];
  for (const tab of relamanhuaRankTabs) {
    const comics = byTab[tab[0]];
    if (comics && comics.length > 0) sections.push({ title: tab[1], comics });
  }
  return sections;
}

/**
 * @param {string} html
 * @returns {ComicPage}
 */
function relamanhuaCatalogPage(html) {
  const doc = Hazuki.html.parse(html);
  try {
    /** @type {SourceComic[]} */
    const comics = [];
    for (const card of doc.querySelectorAll(".exemptComicItem")) {
      const anchor = card.querySelector("a");
      const image = card.querySelector("img");
      if (!anchor || !image) continue;
      const id = relamanhuaComicIdFromHref(anchor.attributes.href);
      const cover = relamanhuaAbsolute(
        relamanhuaText(image.attributes.src) ||
          relamanhuaText(image.attributes["data-src"]),
      );
      if (!id || !cover) continue;
      comics.push({ id, title: relamanhuaNodeTitle(card) || id, cover });
    }
    let maxPage = 1;
    for (const node of doc.querySelectorAll(".page-total")) {
      const match = /\/(\d+)/.exec(relamanhuaText(node.text));
      if (match) maxPage = Math.max(1, Number(match[1]));
    }
    return { comics, maxPage };
  } finally {
    doc.dispose();
  }
}

/**
 * @param {string} type "1" free, "2" paid
 * @param {string} theme theme slug, or "" for every theme
 * @param {string} ordering sort key used by the site
 * @param {number} page 1-based page number; the site pages by 50
 * @param {string} [female] paid comic female tag slug
 * @param {string} [male] paid comic male tag slug
 * @returns {Promise<ComicPage>}
 */
async function relamanhuaLoadCatalog(
  type,
  theme,
  ordering,
  page,
  female,
  male,
) {
  const currentPage = Number(page) > 0 ? Math.floor(Number(page)) : 1;
  const offset = (currentPage - 1) * relamanhuaCatalogLimit;
  let query =
    "/comics?type=" +
    (type === "2" ? "2" : "1") +
    "&ordering=" +
    encodeURIComponent(ordering || "-datetime_updated") +
    "&offset=" +
    offset +
    "&limit=" +
    relamanhuaCatalogLimit;
  if (theme) query += "&theme=" + encodeURIComponent(theme);
  if (type === "2") {
    if (female) query += "&female=" + encodeURIComponent(female);
    if (male) query += "&male=" + encodeURIComponent(male);
  }
  return relamanhuaCatalogPage(await relamanhuaGet(query, ""));
}

/**
 * The homepage recommendation preview links to /recommend, which has its own
 * 60-item pagination and must not be replaced by the general comic catalogue.
 * @param {number} page
 * @returns {Promise<ComicPage>}
 */
async function relamanhuaLoadRecommendations(page) {
  const currentPage = Number(page) > 0 ? Math.floor(Number(page)) : 1;
  const offset = (currentPage - 1) * relamanhuaRecommendLimit;
  return relamanhuaCatalogPage(
    await relamanhuaGet(
      "/recommend?type=1200102&offset=" +
        offset +
        "&limit=" +
        relamanhuaRecommendLimit,
      "",
    ),
  );
}

/**
 * The token is optional: a failure to read it must degrade to an anonymous
 * read rather than break every page.
 * @returns {string}
 */
function relamanhuaToken() {
  try {
    const value = Hazuki.storage.get("token");
    return typeof value === "string" ? value.trim() : "";
  } catch (error) {
    return "";
  }
}

/**
 * @param {string} token
 * @param {string} accept
 * @returns {Record<string, string>}
 */
function relamanhuaAuthHeaders(token, accept) {
  const headers = relamanhuaHeaders(accept);
  if (token) headers.Authorization = "Token " + token;
  return headers;
}

/**
 * Parse a {code, message, results} envelope, or {detail} with a 4xx status.
 * @param {string} body
 * @param {string} action
 * @param {number} [status] HTTP status used when the body carries no message.
 * @returns {any}
 */
function relamanhuaJsonResults(body, action, status) {
  /** @type {any} */
  let payload = null;
  try {
    payload = JSON.parse(body);
  } catch (error) {
    payload = null;
  }
  if (payload && Number(payload.code) === 200) return payload.results;
  const detail = payload
    ? relamanhuaText(payload.message) || relamanhuaText(payload.detail)
    : "";
  const fallback = status ? "HTTP " + status : "响应格式异常";
  throw new Error(action + "失败：" + (detail || fallback));
}

/**
 * @param {SourceHttpResponse<string>} response
 * @param {string} action
 * @returns {any}
 */
function relamanhuaApiResults(response, action) {
  return relamanhuaJsonResults(response.body, action, response.status);
}

/**
 * API image paths are relative to the asset host; absolute values pass through.
 * @param {unknown} value
 * @returns {string}
 */
function relamanhuaAssetUrl(value) {
  const raw = relamanhuaText(value);
  if (!raw) return "";
  if (/^https?:\/\//i.test(raw)) return raw;
  if (raw.indexOf("//") === 0) return "https:" + raw;
  return relamanhuaAssetHost + (raw.charAt(0) === "/" ? raw : "/" + raw);
}

/**
 * @param {string} token
 * @returns {Promise<SourceProfile>}
 */
async function relamanhuaFetchProfile(token) {
  const response = await Hazuki.http.get(
    relamanhuaBase() + "/api/v2/web/user/info",
    relamanhuaAuthHeaders(token, "application/json"),
  );
  const results = relamanhuaApiResults(response, "获取用户信息");
  /** @type {SourceProfile} */
  const profile = { token };
  const name = relamanhuaText(results && results.nickname);
  if (name) profile.displayName = name;
  const avatar = relamanhuaAssetUrl(results && results.avatar);
  if (avatar) profile.avatarUrl = avatar;
  return profile;
}

/**
 * The site signs in with Base64(password + "-" + salt); the salt is sent beside
 * it so the server can rebuild the password.
 * @param {string} account
 * @param {string} password
 * @returns {Promise<SourceProfile>}
 */
async function relamanhuaLogin(account, password) {
  const user = relamanhuaText(account);
  if (!user) throw new Error("请输入账号");
  const secret = String(
    password === null || password === undefined ? "" : password,
  );
  if (!secret) throw new Error("请输入密码");
  const salt = String(100000 + Math.floor(Math.random() * 900000));
  const body = [
    "username=" + encodeURIComponent(user),
    "password=" +
      encodeURIComponent(relamanhuaBase64Encode(secret + "-" + salt)),
    "salt=" + salt,
    "code=",
    "platform=2",
    "version=" + encodeURIComponent(relamanhuaClientVersion),
    "source=",
  ].join("&");
  const headers = relamanhuaHeaders("application/json");
  headers["Content-Type"] = "application/x-www-form-urlencoded;charset=utf-8";
  const response = await Hazuki.http.post(
    relamanhuaBase() + "/api/v1/login",
    headers,
    body,
  );
  const results = relamanhuaApiResults(response, "登录");
  const token = relamanhuaText(results && results.token);
  if (!token) throw new Error("登录失败：服务器没有返回 token");
  // Persist before anything else so a later failure cannot lose the session.
  await Hazuki.storage.set("token", token);
  /** @type {SourceProfile} */
  const profile = { token };
  const name = relamanhuaText(results && results.nickname);
  if (name) profile.displayName = name;
  const avatar = relamanhuaAssetUrl(results && results.avatar);
  if (avatar) profile.avatarUrl = avatar;
  return profile;
}

/**
 * @returns {Promise<void>}
 */
async function relamanhuaLogout() {
  const token = relamanhuaToken();
  try {
    if (token) {
      await Hazuki.http.post(
        relamanhuaBase() + "/api/v1/logout",
        relamanhuaAuthHeaders(token, "application/json"),
        "",
      );
    }
  } catch (error) {
    // Signing out locally must succeed even if the server call fails.
  }
  await Hazuki.storage.delete("token");
}

/**
 * @param {string} value
 * @returns {string}
 */
function relamanhuaOrdering(value) {
  const key = relamanhuaText(value);
  return relamanhuaOrderings[key] || "-datetime_updated";
}

/**
 * The host splits options on the first dash. Escape slugs that contain one,
 * and encode spaces without changing the site's original tag identifiers.
 * @param {string} slug
 * @returns {string}
 */
function relamanhuaTagOptionValue(slug) {
  return encodeURIComponent(slug).replace(/-/g, "%2D");
}

/**
 * Resolve host option values back to the original site slugs. Also accept raw
 * slugs for callers that do not use the encoded option list.
 * @param {string | undefined} value
 * @param {string[][]} tags
 * @returns {string}
 */
function relamanhuaSelectedTag(value, tags) {
  if (!value) return "";
  for (const tag of tags) {
    if (value === tag[0] || value === relamanhuaTagOptionValue(tag[0])) {
      return tag[0];
    }
  }
  return "";
}

/**
 * Form-encode a flat object the way the site's own client does.
 * @param {Record<string, string | number>} values
 * @returns {string}
 */
function relamanhuaFormBody(values) {
  return Object.keys(values)
    .map(
      (key) =>
        encodeURIComponent(key) + "=" + encodeURIComponent(String(values[key])),
    )
    .join("&");
}

/**
 * Rank, rack and search payloads wrap the comic as {comic: {...}}; accept a
 * flat object too so a shape change cannot blank the list.
 * @param {any} item
 * @returns {SourceComic}
 */
function relamanhuaNestedComic(item) {
  const node =
    item && item.comic && typeof item.comic === "object" ? item.comic : item;
  const pathWord = relamanhuaText(node && node.path_word);
  /** @type {SourceComic} */
  const comic = {
    id: pathWord,
    title: relamanhuaText(node && node.name) || pathWord,
    cover: relamanhuaAbsolute(node && node.cover),
  };
  const themes = relamanhuaNameList(node && node.theme);
  if (themes.length) comic.tags = themes;
  return comic;
}

/**
 * @param {any} results
 * @param {number} fallbackPage
 * @returns {ComicPage}
 */
function relamanhuaRankPage(results, fallbackPage) {
  const list = results && Array.isArray(results.list) ? results.list : [];
  /** @type {SourceComic[]} */
  const comics = [];
  for (const item of list) {
    const comic = relamanhuaNestedComic(item);
    if (comic.id) comics.push(comic);
  }
  const total = Number(results && results.total);
  const limit =
    Number(results && results.limit) > 0 ? Number(results.limit) : 20;
  const maxPage =
    Number.isFinite(total) && total > 0
      ? Math.max(1, Math.ceil(total / limit))
      : fallbackPage;
  return { comics, maxPage };
}

/**
 * Ranking rail: /api/v3/ranks?type=&date_type= pages by offset/limit and
 * reports a total, unlike the /rank page which only shows a fixed top ten.
 * @param {string} option value such as "1d" (free, day)
 * @param {number} page 1-based
 * @returns {Promise<ComicPage>}
 */
async function relamanhuaLoadRanking(option, page) {
  const key = relamanhuaText(option) || "1d";
  let rail = relamanhuaRankOptions[0];
  for (const candidate of relamanhuaRankOptions) {
    if (candidate[0] === key) {
      rail = candidate;
      break;
    }
  }
  const currentPage = Number(page) > 0 ? Math.floor(Number(page)) : 1;
  const limit = 20;
  const body = await relamanhuaGet(
    "/api/v3/ranks?type=" +
      rail[1] +
      "&date_type=" +
      rail[2] +
      "&limit=" +
      limit +
      "&offset=" +
      (currentPage - 1) * limit,
    "application/json",
  );
  return relamanhuaRankPage(
    relamanhuaJsonResults(body, "获取排行榜"),
    currentPage,
  );
}

/**
 * Per-comic facts Hazuki needs but the rendered page does not carry: the
 * internal uuid (collect/comments key on it), whether this account collected
 * the title, and whether the site locks it to a trial. Cached per session.
 * @type {Record<string, {uuid: string, collected: boolean, locked: boolean}>}
 */
const relamanhuaMetaCache = {};

/**
 * @param {string} pathWord
 * @returns {Promise<{uuid: string, collected: boolean, locked: boolean}>}
 */
async function relamanhuaComicMeta(pathWord) {
  const key = relamanhuaText(pathWord);
  if (!key) throw new Error("缺少漫画 ID");
  if (relamanhuaMetaCache[key]) return relamanhuaMetaCache[key];
  const response = await relamanhuaOptionalAuthGet(
    "/api/v3/comic/" + encodeURIComponent(key),
  );
  const results = relamanhuaApiResults(response, "获取漫画信息");
  const comic = (results && results.comic) || {};
  const uuid = relamanhuaText(comic.uuid);
  if (!uuid) throw new Error("无法解析漫画 ID：" + key);
  const collected =
    results && results.collect !== null && results.collect !== undefined;
  const meta = {
    uuid,
    collected: Boolean(collected),
    locked: Boolean(results && results.is_lock),
  };
  relamanhuaMetaCache[key] = meta;
  return meta;
}

/**
 * @param {string} pathWord
 * @returns {Promise<string>}
 */
async function relamanhuaUuidFor(pathWord) {
  return (await relamanhuaComicMeta(pathWord)).uuid;
}

/**
 * @param {number} page 1-based
 * @returns {Promise<ComicPage>}
 */
async function relamanhuaFavoriteComics(page) {
  const currentPage = Number(page) > 0 ? Math.floor(Number(page)) : 1;
  const body = await relamanhuaApiResults(
    await relamanhuaAuthedGet(
      "/api/v3/member/collect/comics?free_type=1&limit=" +
        relamanhuaFavoritePageSize +
        "&offset=" +
        (currentPage - 1) * relamanhuaFavoritePageSize,
    ),
    "加载收藏",
  );
  return relamanhuaRankPage(body, currentPage);
}

/**
 * Reads may be public, so the token is attached only when a session exists.
 * @param {string} path path including the query string.
 * @returns {Promise<SourceHttpResponse<string>>}
 */
async function relamanhuaOptionalAuthGet(path) {
  return Hazuki.http.get(
    relamanhuaBase() + path,
    relamanhuaAuthHeaders(relamanhuaToken(), "application/json"),
  );
}

/**
 * @param {string} path path including the query string.
 * @returns {Promise<SourceHttpResponse<string>>}
 */
async function relamanhuaAuthedGet(path) {
  const token = relamanhuaToken();
  if (!token) throw new Error("请先登录账号");
  return Hazuki.http.get(
    relamanhuaBase() + path,
    relamanhuaAuthHeaders(token, "application/json"),
  );
}

/**
 * @param {string} path
 * @param {Record<string, string | number>} values
 * @returns {Promise<SourceHttpResponse<string>>}
 */
async function relamanhuaAuthedPost(path, values) {
  const token = relamanhuaToken();
  if (!token) throw new Error("请先登录账号");
  const headers = relamanhuaAuthHeaders(token, "application/json");
  headers["Content-Type"] = "application/x-www-form-urlencoded;charset=utf-8";
  return Hazuki.http.post(
    relamanhuaBase() + path,
    headers,
    relamanhuaFormBody(values),
  );
}

/**
 * @param {string} comicId
 * @param {boolean} adding
 * @returns {Promise<void>}
 */
async function relamanhuaSetFavorite(comicId, adding) {
  const meta = await relamanhuaComicMeta(comicId);
  const response = await relamanhuaAuthedPost("/api/v3/member/collect/comic", {
    comic_id: meta.uuid,
    is_collect: adding ? 1 : 0,
  });
  relamanhuaApiResults(response, adding ? "加入书架" : "移出书架");
  // Keep the cached state in step so the detail page shows the new value.
  meta.collected = Boolean(adding);
}

/**
 * Hazuki asks for the comic's folders to render the favourite state. The site
 * has a single implicit shelf, so report that one folder plus membership.
 * @param {string | null} comicId
 * @returns {Promise<{folders: Record<string, string>, favorited?: string[]}>}
 */
async function relamanhuaLoadFolders(comicId) {
  const folders = { shelf: "書架" };
  const pathWord = relamanhuaText(comicId);
  if (!pathWord) return { folders };
  try {
    const meta = await relamanhuaComicMeta(pathWord);
    return { folders, favorited: meta.collected ? ["shelf"] : [] };
  } catch (error) {
    Hazuki.log("获取收藏状态失败：" + relamanhuaErrorText(error));
    return { folders };
  }
}

/**
 * The site ships no comment service on this deployment: every /api/v3/comments
 * and /api/v3/roasts route answers the 404 upgrade page. Report that as an
 * empty list so the reader renders instead of failing on a missing method.
 * @param {SourceHttpResponse<string>} response
 * @param {string} action
 * @returns {boolean} true when the route is simply absent.
 */
function relamanhuaRouteMissing(response, action) {
  const body = response.body || "";
  const missing =
    response.status === 404 ||
    response.status === 405 ||
    /<!DOCTYPE|<html/i.test(body);
  if (missing) Hazuki.log("热辣漫画暂未提供" + action + "服务，已按空结果处理");
  return missing;
}

/**
 * @param {any} item
 * @returns {SourceComment | null}
 */
function relamanhuaCommentFrom(item) {
  if (!item || typeof item !== "object") return null;
  const id = relamanhuaText(item.uuid) || relamanhuaText(item.id);
  const content = relamanhuaText(item.comment);
  if (!id || !content) return null;
  /** @type {SourceComment} */
  const comment = {
    id,
    userName: relamanhuaText(item.user_name) || "匿名",
    content,
  };
  const avatar = relamanhuaAssetUrl(item.user_avatar);
  if (avatar) comment.avatar = avatar;
  const time =
    relamanhuaText(item.datetime_created) || relamanhuaText(item.create_at);
  if (time) comment.time = time;
  if (item.count !== undefined && item.count !== null)
    comment.replyCount = Number(item.count) || 0;
  return comment;
}

/**
 * @param {SourceHttpResponse<string>} response
 * @param {string} action
 * @returns {{comments: SourceComment[]; maxPage?: number}}
 */
function relamanhuaCommentPage(response, action) {
  if (relamanhuaRouteMissing(response, action))
    return { comments: [], maxPage: 1 };
  const results = relamanhuaApiResults(response, action);
  const list = results && Array.isArray(results.list) ? results.list : [];
  /** @type {SourceComment[]} */
  const comments = [];
  for (const item of list) {
    const comment = relamanhuaCommentFrom(item);
    if (comment) comments.push(comment);
  }
  const total = Number(results && results.total);
  const limit =
    Number(results && results.limit) > 0
      ? Number(results.limit)
      : relamanhuaCommentPageSize;
  const maxPage =
    Number.isFinite(total) && total > 0
      ? Math.max(1, Math.ceil(total / limit))
      : 1;
  return { comments, maxPage };
}

/**
 * @param {string} comicId
 * @param {number} page 1-based
 * @returns {Promise<{comments: SourceComment[]; maxPage?: number}>}
 */
async function relamanhuaLoadComments(comicId, page) {
  const uuid = await relamanhuaUuidFor(comicId);
  const currentPage = Number(page) > 0 ? Math.floor(Number(page)) : 1;
  const response = await relamanhuaOptionalAuthGet(
    "/api/v3/comments?comic_id=" +
      encodeURIComponent(uuid) +
      "&limit=" +
      relamanhuaCommentPageSize +
      "&offset=" +
      (currentPage - 1) * relamanhuaCommentPageSize,
  );
  return relamanhuaCommentPage(response, "漫画评论");
}

/**
 * Chapter discussion uses the site's "roast" endpoints.
 * @param {string} chapterId
 * @param {number} page 1-based
 * @returns {Promise<{comments: SourceComment[]; maxPage?: number}>}
 */
async function relamanhuaLoadChapterComments(chapterId, page) {
  const chapter = relamanhuaText(chapterId);
  if (!chapter) throw new Error("缺少章节 ID");
  const currentPage = Number(page) > 0 ? Math.floor(Number(page)) : 1;
  const response = await relamanhuaOptionalAuthGet(
    "/api/v3/roasts?chapter_id=" +
      encodeURIComponent(chapter) +
      "&limit=" +
      relamanhuaCommentPageSize +
      "&offset=" +
      (currentPage - 1) * relamanhuaCommentPageSize,
  );
  return relamanhuaCommentPage(response, "章节评论");
}

/**
 * @param {SourceHttpResponse<string>} response
 * @param {string} action
 * @returns {void}
 */
function relamanhuaCommentPosted(response, action) {
  if (relamanhuaRouteMissing(response, action)) {
    throw new Error("热辣漫画暂未开放" + action + "功能");
  }
  relamanhuaApiResults(response, action);
}

/**
 * @param {string} comicId
 * @param {string} text
 * @param {string | null} replyTo
 * @returns {Promise<void>}
 */
async function relamanhuaSendComment(comicId, text, replyTo) {
  const content = relamanhuaText(text);
  if (!content) throw new Error("评论内容不能为空");
  const uuid = await relamanhuaUuidFor(comicId);
  relamanhuaCommentPosted(
    await relamanhuaAuthedPost("/api/v3/member/comment", {
      comic_id: uuid,
      comment: content,
      reply_id: relamanhuaText(replyTo),
    }),
    "发表评论",
  );
}

/**
 * @param {string} chapterId
 * @param {string} text
 * @returns {Promise<void>}
 */
async function relamanhuaSendChapterComment(chapterId, text) {
  const content = relamanhuaText(text);
  if (!content) throw new Error("评论内容不能为空");
  const chapter = relamanhuaText(chapterId);
  if (!chapter) throw new Error("缺少章节 ID");
  relamanhuaCommentPosted(
    await relamanhuaAuthedPost("/api/v3/member/roast", {
      chapter_id: chapter,
      roast: content,
    }),
    "发表评论",
  );
}

Hazuki.registerSource({
  id: "relamanhua",
  name: "热辣漫画",
  version: "1.3.4",
  apiVersion: 1,
  presentation: {
    buttons: [
      { id: "imageQuality", location: "reading" },
      { id: "imageQuality", location: "reader" },
    ],
    searchOrders: {
      free: { zh: "免费漫画", en: "Free comics" },
      charge: { zh: "付费漫画", en: "Paid comics" },
    },
    searchDefaultOrder: "free",
    listTagGroups: ["题材", "标签"],
    showTags: true,
    imageQualitySetting: "imageQuality",
    imageQualityTitle: "图片质量",
    imageQualityOptions: {
      jpg: "JPG（清晰）",
      webp: "WebP（省流）",
    },
    imageQualityDefault: "jpg",
  },
  settings: {
    baseUrl: {
      title: { zh: "自定义域名", en: "Custom domain" },
      type: "input",
      default: "",
    },
    imageQuality: {
      title: { zh: "图片质量", en: "Image quality" },
      type: "select",
      options: [{ value: "jpg" }, { value: "webp" }],
      default: "jpg",
    },
  },
  account: {
    login: (account, password) => relamanhuaLogin(account, password),
    logout: () => relamanhuaLogout(),
    loadProfile: async () => {
      const token = relamanhuaToken();
      return token ? relamanhuaFetchProfile(token) : {};
    },
  },
  explore: [
    {
      title: "推薦",
      type: "multiPartPage",
      load: async () => relamanhuaHomeSections(await relamanhuaGet("/", "")),
    },
    {
      title: "排行榜",
      type: "multiPartPage",
      load: async () => {
        const doc = Hazuki.html.parse(await relamanhuaGet("/rank", ""));
        try {
          return relamanhuaRankSections(doc);
        } finally {
          doc.dispose();
        }
      },
    },
    {
      title: "漫畫庫",
      type: "multiPageComicList",
      load: (page) => relamanhuaLoadCatalog("1", "", "-datetime_updated", page),
    },
    {
      title: "付費漫畫",
      type: "multiPageComicList",
      load: (page) => relamanhuaLoadCatalog("2", "", "-datetime_updated", page),
    },
  ],
  category: {
    title: "按類型",
    parts: [
      {
        name: "類型",
        itemType: "category",
        categories: ["免費漫畫", "付費漫畫"],
        categoryParams: ["1", "2"],
      },
    ],
  },
  categoryComics: {
    optionList: [
      {
        label: "題材",
        notShowWhen: ["recommend"],
        options: ["-全部題材"].concat(
          relamanhuaThemes.map((theme) => theme[0] + "-" + theme[1]),
        ),
      },
      {
        label: "排序",
        notShowWhen: ["recommend"],
        // Values must not contain a dash: the host splits each entry on the
        // first dash, so aliases are mapped back to the real ordering strings.
        options: ["updated-最近更新", "popular-最多人氣", "oldest-最早更新"],
      },
      {
        label: "女性標簽",
        showWhen: ["付費漫畫", "2"],
        options: ["-全部女性標簽"].concat(
          relamanhuaFemaleTags.map(
            (tag) => relamanhuaTagOptionValue(tag[0]) + "-" + tag[1],
          ),
        ),
      },
      {
        label: "男性標簽",
        showWhen: ["付費漫畫", "2"],
        options: ["-全部男性標簽"].concat(
          relamanhuaMaleTags.map(
            (tag) => relamanhuaTagOptionValue(tag[0]) + "-" + tag[1],
          ),
        ),
      },
    ],
    ranking: {
      options: relamanhuaRankOptions.map((rail) => rail[0] + "-" + rail[3]),
      load: (option, page) => relamanhuaLoadRanking(option, page),
    },
    load: async (category, param, options, page) =>
      param === "recommend"
        ? relamanhuaLoadRecommendations(page)
        : relamanhuaLoadCatalog(
            param || "1",
            options[0] || "",
            relamanhuaOrdering(options[1]),
            page,
            relamanhuaSelectedTag(options[2], relamanhuaFemaleTags),
            relamanhuaSelectedTag(options[3], relamanhuaMaleTags),
          ),
  },
  favorites: {
    singleFolderForSingleComic: true,
    loadComics: (page) => relamanhuaFavoriteComics(page),
    loadFolders: (comicId) => relamanhuaLoadFolders(comicId),
    addOrDelFavorite: (comicId, folderId, adding) =>
      relamanhuaSetFavorite(comicId, adding),
  },
  search: {
    load: async (keyword, options, page) => {
      const order =
        Array.isArray(options) && options.length > 0 ? String(options[0]) : "";
      const freeType = order === "charge" ? 2 : 1;
      const currentPage = Number(page) > 0 ? Math.floor(Number(page)) : 1;
      const offset = (currentPage - 1) * relamanhuaPageSize;
      const body = await relamanhuaGet(
        "/api/v3/search/comic?offset=" +
          offset +
          "&platform=2&limit=" +
          relamanhuaPageSize +
          "&q=" +
          encodeURIComponent(keyword) +
          "&free_type=" +
          freeType,
        "application/json",
      );
      /** @type {any} */
      let payload;
      try {
        payload = JSON.parse(body);
      } catch (error) {
        throw new Error("搜索接口返回的不是 JSON");
      }
      if (!payload || payload.code !== 200) {
        throw new Error(
          "搜索失败：" + relamanhuaText(payload && payload.message),
        );
      }
      const results = payload.results || {};
      const list = Array.isArray(results.list) ? results.list : [];
      /** @type {SourceComic[]} */
      const comics = [];
      for (const item of list) {
        const comic = relamanhuaComicFromSearch(item);
        if (comic.id) comics.push(comic);
      }
      const total = Number(results.total);
      const limit =
        Number(results.limit) > 0 ? Number(results.limit) : relamanhuaPageSize;
      const maxPage =
        Number.isFinite(total) && total > 0
          ? Math.max(1, Math.ceil(total / limit))
          : currentPage;
      return { comics, maxPage };
    },
  },
  comic: {
    loadInfo: async (id) => {
      const pathWord = relamanhuaText(id);
      if (!pathWord) throw new Error("缺少漫画 ID");
      const html = await relamanhuaGet(
        "/comic/" + encodeURIComponent(pathWord),
        "",
      );
      const doc = Hazuki.html.parse(html);
      try {
        const keyNode = doc.querySelector(".disposablePass");
        const keyText = keyNode
          ? relamanhuaText(keyNode.attributes.disposable)
          : "";
        const details = relamanhuaParseDetail(doc, pathWord);
        details.chapters = await relamanhuaLoadChapters(
          pathWord,
          keyText || relamanhuaFallbackKey,
        );
        // Neither the collect state nor the trial lock appears in the rendered
        // page, so ask the JSON detail API (one small call, cached for later).
        try {
          const meta = await relamanhuaComicMeta(pathWord);
          details.isFavorite = meta.collected;
          if (meta.locked) {
            const groups = details.tags || {};
            const statuses = groups["状态"] || [];
            statuses.push("付費試看");
            groups["状态"] = statuses;
            details.headerStats = [{ text: statuses.join(" · ") }];
            details.tags = groups;
          }
        } catch (error) {
          Hazuki.log("获取收藏状态失败：" + relamanhuaErrorText(error));
        }
        return details;
      } finally {
        doc.dispose();
      }
    },
    loadEp: async (comicId, chapterId) => {
      const pathWord = relamanhuaText(comicId);
      const chapter = relamanhuaText(chapterId);
      if (!pathWord || !chapter) throw new Error("缺少漫画或章节 ID");
      const html = await relamanhuaGet(
        "/comic/" +
          encodeURIComponent(pathWord) +
          "/chapter/" +
          encodeURIComponent(chapter),
        "",
      );
      const keyText =
        relamanhuaPageVariable(html, "cct") || relamanhuaFallbackKey;
      const blob = relamanhuaPageVariable(html, "contentKey");
      if (!blob) throw new Error("章节页面没有可解密的数据");
      /** @type {any} */
      let list;
      try {
        list = JSON.parse(relamanhuaDecryptBlob(blob, keyText));
      } catch (error) {
        throw new Error("章节图片解密失败：" + relamanhuaErrorText(error));
      }
      if (!Array.isArray(list)) throw new Error("章节图片数据格式异常");
      const quality = relamanhuaImageQuality();
      /** @type {string[]} */
      const images = [];
      for (const entry of list) {
        if (!entry || typeof entry.url !== "string") continue;
        const url = relamanhuaApplyQuality(
          relamanhuaAbsolute(entry.url),
          quality,
        );
        if (url) images.push(url);
      }
      if (images.length === 0) throw new Error("没有解析到任何图片");
      return { images };
    },
    loadComments: (id, subId, page) => relamanhuaLoadComments(id, page),
    loadChapterComments: (id, chapterId, page) =>
      relamanhuaLoadChapterComments(chapterId, page),
    sendComment: (id, subId, text, replyTo) =>
      relamanhuaSendComment(id, text, replyTo),
    sendChapterComment: (id, chapterId, text) =>
      relamanhuaSendChapterComment(chapterId, text),
  },
});
