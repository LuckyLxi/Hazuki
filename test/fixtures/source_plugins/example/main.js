const cover = 'https://example.com/cover.png';
Hazuki.registerSource({
    id: "example",
    name: "Hazuki Example",
    version: "1.0.0",
    presentation: {"searchOrders":{"latest":"Latest"},"searchDefaultOrder":"latest","dailyRecommendation":{"mode":"plugin"}},
    search: {load: async (keyword, options, page) => ({
        comics: page === 1 ? [{id: 'demo', title: keyword || 'Example comic', cover}] : [], maxPage: 1,
    })},
    dailyRecommendation: {load: async () => [
        {id: 'demo', title: 'Website daily pick', cover, imageUrl: 'https://example.com/banner.png', caption: '每日精选'},
    ]},
    comic: {
        loadInfo: async id => ({id, title: 'Example comic', cover, chapters: {'1':'Chapter 1'}, tags: {}, headerStats: [{text: {zh: '每周更新', en: 'Weekly updates'}}], infoFields: [{label: {zh: '状态', en: 'Status'}, values: '连载中'}], description: 'Hazuki Source API v1 example'}),
        loadEp: async (comicId, chapterId) => ({images: ['https://example.com/page-1.png']}),
    },
    resources: {'about.txt': 'Hazuki Source API v1 example'},
    settings: {language: {title: {zh: '语言', en: 'Language'}, type: 'select', options: [{value:'en',label:{zh:'英语',en:'English'}},{value:'zh',label:{zh:'中文',en:'Chinese'}}], default:'en'}},
});
