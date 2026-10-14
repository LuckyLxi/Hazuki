const cover = 'https://example.com/cover.png';
Hazuki.registerSource({
    id: "example",
    name: "Hazuki Example",
    version: "1.0.0",
    presentation: {"searchOrders":{"latest":"Latest"},"searchDefaultOrder":"latest"},
    search: {load: async (keyword, options, page) => ({
        comics: page === 1 ? [{id: 'demo', title: keyword || 'Example comic', cover}] : [], maxPage: 1,
    })},
    comic: {
        loadInfo: async id => ({id, title: 'Example comic', cover, chapters: {'1':'Chapter 1'}, tags: {}, description: 'Hazuki Source API v1 example'}),
        loadEp: async (comicId, chapterId) => ({images: ['https://example.com/page-1.png']}),
    },
    resources: {'about.txt': 'Hazuki Source API v1 example'},
    settings: {language: {title: {zh: '语言', en: 'Language'}, type: 'select', options: [{value:'en',label:{zh:'英语',en:'English'}},{value:'zh',label:{zh:'中文',en:'Chinese'}}], default:'en'}},
});
