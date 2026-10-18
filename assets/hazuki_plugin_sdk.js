// Hazuki Source API v1. Identity comes from the registered source.
class HazukiSource extends ComicSource {}

const Hazuki = (() => {
let sourceKey;
return Object.freeze({
    apiVersion: 1,
    get locale() { return APP.locale; },
    translate: text => __hazukiLocalizeText(text, globalThis.__hazuki_source?.translation),
    registerSource(source) {
        if (globalThis.__hazuki_source) throw new Error('plugin_duplicate_registration');
        if (!source || typeof source.search?.load !== 'function' ||
            typeof source.comic?.loadInfo !== 'function' ||
            typeof source.comic?.loadEp !== 'function') {
            throw new Error('plugin_required_capability_missing');
        }
        const key = source.id || source.key;
        if (typeof key !== 'string' || !/^[a-z][a-z0-9_.-]{0,63}$/.test(key)) {
            throw new Error('plugin_invalid_identity');
        }
        sourceKey = key;
        Object.defineProperties(source, {
            key: {value: key, writable: false, configurable: false, enumerable: true},
            name: {value: source.name || key, writable: false, configurable: false, enumerable: true},
            version: {value: source.version || '0.0.0', writable: false, configurable: false, enumerable: true},
        });
        source.settings ??= {};
        source.presentation ??= {};
        globalThis.__hazuki_source = source;
    },
    http: Network,
    html: Object.freeze({parse: html => new HtmlDocument(html)}),
    cookies: Object.freeze({
        get: url => sendMessage({method: 'cookie', function: 'get', url}),
        set: (url, cookies) => sendMessage({method: 'cookie', function: 'set', url, cookies}),
        delete: url => sendMessage({method: 'cookie', function: 'delete', url}),
    }),
    storage: Object.freeze({
        get: key => sendMessage({method: 'load_data', key: sourceKey, data_key: key}),
        set: (key, value) => sendMessage({method: 'save_data', key: sourceKey, data_key: key, data: value}),
        delete: key => sendMessage({method: 'delete_data', key: sourceKey, data_key: key}),
    }),
    secrets: Object.freeze({
        get: key => sendMessage({method: 'secret_get', secret_key: key}),
        set: (key, value) => sendMessage({method: 'secret_set', secret_key: key, value}),
        delete: key => sendMessage({method: 'secret_delete', secret_key: key}),
    }),
    settings: Object.freeze({
        get: key => sendMessage({method: 'load_setting', key: sourceKey, setting_key: key,
            default_value: globalThis.__hazuki_source?.settings?.[key]?.default}),
        set: (key, value) => sendMessage({method: 'save_setting', key: sourceKey, setting_key: key, value}),
    }),
    resources: Object.freeze({async readText(path) {
        const resources = globalThis.__hazuki_source?.resources;
        if (!resources || !Object.prototype.hasOwnProperty.call(resources, path) ||
            typeof resources[path] !== 'string') throw new Error('plugin_resource_missing');
        return resources[path];
    }}),
    images: Object.freeze({reverseVerticalTiles(segments) {
        if (!Number.isInteger(segments) || segments < 0 || segments > 4096) throw new Error('plugin_invalid_image_segments');
        return {segments};
    }}),
    convert: Convert,
    log: (message, level = 'info') => sendMessage({method: 'log', level, title: 'Plugin', content: message}),
    delay: ms => sendMessage({method: 'delay', time: ms}),
    error(code, message) { return new Error(`HAZUKI_${code}: ${message}`); },
});
})();

// Only an isolated foreground login runtime installs this host capability.
function __hazukiCreateLoginContext(method) {
    return Object.freeze({
        method,
        requestText: options => sendMessage({method: 'login_interaction', request: {...options, type: 'text'}}),
        requestClickCaptcha: options => sendMessage({method: 'login_interaction', request: {...options, type: 'clickCaptcha'}}),
        requestBrowserAuthorization: options => sendMessage({method: 'login_interaction', request: {...options, type: 'browserAuthorization'}}),
        async requestExternalAuthorization(options) {
            if (typeof options?.createUrl !== 'function') throw new Error('login_invalid_external_options');
            const {createUrl, ...configuration} = options;
            const session = await sendMessage({method: 'login_external_prepare', request: configuration});
            try {
                const url = await createUrl(session.callbackUrl);
                return await sendMessage({method: 'login_interaction', request: {
                    title: options.title, id: session.id, url, type: 'externalAuthorization',
                }});
            } finally {
                await sendMessage({method: 'login_external_close', id: session.id});
            }
        },
    });
}
