// Hazuki Source API v1. Identity comes from the registered source.
const {Hazuki, HazukiSource} = (() => {
// 取走 init.js 的内部实现后删除临时入口，插件只能经由 Hazuki.* 使用这些能力。
const {Network, Convert, HtmlDocument, getLocale, localizeText} = globalThis.__hazukiRuntime;
delete globalThis.__hazukiRuntime;

class HazukiSource {
    name = '';

    key = '';

    version = '';

    translation = {};

    loadData(dataKey) {
        return sendMessage({method: 'load_data', key: this.key, data_key: dataKey});
    }

    loadSetting(key) {
        return sendMessage({method: 'load_setting', key: this.key, setting_key: key});
    }

    saveData(dataKey, data) {
        return sendMessage({method: 'save_data', key: this.key, data_key: dataKey, data});
    }

    deleteData(dataKey) {
        return sendMessage({method: 'delete_data', key: this.key, data_key: dataKey});
    }

    get isLogged() {
        return sendMessage({method: 'isLogged', key: this.key});
    }

    translate(key) {
        return localizeText(key, this.translation);
    }

    init() { }
}

let sourceKey;
const Hazuki = Object.freeze({
    apiVersion: 1,
    get locale() { return getLocale(); },
    translate: text => localizeText(text, globalThis.__hazuki_source?.translation),
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
    }, regions(regions, size = {}) {
        // 宿主会再次严格校验边界，这里只拦截明显的格式错误。
        const isIndex = value => Number.isInteger(value) && value >= 0;
        if (!Array.isArray(regions) || regions.length > 4096 ||
            !regions.every(r => r && ['sx', 'sy', 'sw', 'sh', 'dx', 'dy'].every(k => isIndex(r[k])) &&
                r.sw > 0 && r.sh > 0) ||
            (size.width != null && !(isIndex(size.width) && size.width > 0)) ||
            (size.height != null && !(isIndex(size.height) && size.height > 0))) {
            throw new Error('plugin_invalid_image_regions');
        }
        return {width: size.width, height: size.height,
            regions: regions.map(({sx, sy, sw, sh, dx, dy}) => ({sx, sy, sw, sh, dx, dy}))};
    }}),
    convert: Convert,
    log: (message, level = 'info') => sendMessage({method: 'log', level, title: 'Plugin', content: message}),
    delay: ms => sendMessage({method: 'delay', time: ms}),
    error(code, message) { return new Error(`HAZUKI_${code}: ${message}`); },
    ui: (() => {
        // QuickJS exposes ArrayBuffer as native bytes. Typed-array views must
        // retain only their selected range before crossing the host bridge.
        function serializeImages(options) {
            if (!Array.isArray(options?.content)) return options;
            const bytes = value => value instanceof Uint8Array
                ? value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength)
                : value;
            // row 的子组件同样可能携带图片，需要递归处理。
            const serialize = content => content.map(component => {
                if (!component || typeof component !== 'object') return component;
                return {...component,
                    ...(component.image != null ? {image: bytes(component.image)} : {}),
                    ...(component.hintImage != null ? {hintImage: bytes(component.hintImage)} : {}),
                    ...(Array.isArray(component.children) ? {children: serialize(component.children)} : {}),
                };
            });
            return {...options, content: serialize(options.content)};
        }
        class PluginDialogCancelledError extends Error {
            constructor(reason = 'user') {
                super(`plugin_ui_cancelled:${reason}`);
                this.name = 'PluginDialogCancelledError';
                this.code = 'plugin_ui_cancelled';
                this.reason = reason;
            }
        }
        async function simpleDialog(kind, options) {
            const content = [];
            if (options.message != null) content.push({id: 'message', type: 'text', text: options.message});
            if (kind === 'prompt') {
                const {label, initialValue, placeholder, obscure, keyboardType, required, maxLength} = options;
                content.push({id: 'value', type: 'input', label, initialValue, placeholder,
                    obscure, keyboardType, required, maxLength});
            }
            const buttons = kind === 'alert' ? [] : [{id: 'cancel',
                text: options.cancelText ?? {zh_CN: '取消', en_US: 'Cancel'}}];
            buttons.push({id: 'confirm', text: options.confirmText ?? {zh_CN: '确定', en_US: 'OK'},
                role: 'primary', validate: true});
            const dialog = await Hazuki.ui.openDialog({title: options.title, content, buttons});
            try {
                const event = await dialog.nextEvent();
                if (event.type === 'closed') throw new PluginDialogCancelledError(event.reason);
                if (kind === 'alert') return;
                if (kind === 'confirm') return event.id === 'confirm';
                return event.id === 'confirm' ? event.values.value : null;
            } finally {
                await dialog.close();
            }
        }
        function browserRequest(options) {
            const created = Promise.resolve().then(() =>
                sendMessage({method: 'ui_browser_create', options}));
            const result = created.then(id => sendMessage({method: 'ui_browser_result', id}));
            // Plugins may only close the window and never await its outcome.
            result.catch(() => {});
            let closing;
            Object.defineProperty(result, 'close', {value() {
                return closing ??= created.then(async id => {
                    try {
                        await sendMessage({method: 'ui_browser_close', id});
                    } catch (error) {
                        if (!String(error).includes('plugin_ui_unavailable') &&
                            !String(error).includes('plugin_ui_cancelled')) throw error;
                    }
                });
            }});
            return Object.freeze(result);
        }
        return Object.freeze({
            PluginDialogCancelledError,
            // 3：支持 rating/row/button/comics/tags/info/richText 与 sheet 展示。
            dialogVersion: 3,
            isAvailable: async () => sendMessage({method: 'ui_available'}),
            openWebView: options => browserRequest({
                completion: options?.callbacks?.length ? 'callback' : 'manual', ...options,
            }),
            requestBrowserAuthorization: browserRequest,
            alert: options => simpleDialog('alert', options),
            confirm: options => simpleDialog('confirm', options),
            prompt: options => simpleDialog('prompt', options),
            async openDialog(options) {
                const id = await sendMessage({method: 'ui_open', options: serializeImages(options)});
                let terminal;
                return Object.freeze({
                    async nextEvent() {
                        if (terminal) return terminal;
                        const event = await sendMessage({method: 'ui_next_event', id});
                        if (event.type === 'closed') terminal = event;
                        return event;
                    },
                    async update(patch) {
                        if (terminal) throw new Error('plugin_ui_closed');
                        await sendMessage({method: 'ui_update', id, patch: serializeImages(patch)});
                    },
                    async close() {
                        if (terminal) return;
                        try {
                            await sendMessage({method: 'ui_close', id});
                        } catch (error) {
                            if (!String(error).includes('plugin_ui_unavailable') &&
                                !String(error).includes('plugin_ui_cancelled')) throw error;
                        }
                        terminal = {type: 'closed', reason: 'plugin'};
                    },
                });
            },
        });
    })(),
});
return {Hazuki, HazukiSource};
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
