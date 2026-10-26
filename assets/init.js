/*
Hazuki 宿主底层桥接库（内部）。

在插件脚本之前注入，只为 hazuki_plugin_sdk.js 提供实现；插件只能通过 Hazuki.* 访问这些能力。
除 setTimeout、setInterval、console 等通用 JS 能力外，不向插件暴露任何全局对象。
*/

/**
 * @function sendMessage
 * @global
 * @param {Object} message
 * @returns {any}
 */

(() => {
/**
 * Set a timeout to execute a callback function after a specified delay.
 * @param callback {Function}
 * @param delay {number} - delay in milliseconds
 */
globalThis.setTimeout = function setTimeout(callback, delay) {
    sendMessage({
        method: 'delay',
        time: delay,
    }).then(callback);
};

/// encode, decode, hash, decrypt
let Convert = {
    /**
     * @param str {string}
     * @returns {ArrayBuffer}
     */
    encodeUtf8: (str) => {
        return sendMessage({
            method: "convert",
            type: "utf8",
            value: str,
            isEncode: true
        });
    },

    /**
     * @param value {ArrayBuffer}
     * @returns {string}
     */
    decodeUtf8: (value) => {
        return sendMessage({
            method: "convert",
            type: "utf8",
            value: value,
            isEncode: false
        });
    },

    /**
     * @param str {string}
     * @returns {ArrayBuffer}
     */
    encodeGbk: (str) => {
        return sendMessage({
            method: "convert",
            type: "gbk",
            value: str,
            isEncode: true
        });
    },

    /**
     * @param value {ArrayBuffer}
     * @returns {string}
     */
    decodeGbk: (value) => {
        return sendMessage({
            method: "convert",
            type: "gbk",
            value: value,
            isEncode: false
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @returns {string}
     */
    encodeBase64: (value) => {
        return sendMessage({
            method: "convert",
            type: "base64",
            value: value,
            isEncode: true
        });
    },

    /**
     * @param {string} value
     * @returns {ArrayBuffer}
     */
    decodeBase64: (value) => {
        return sendMessage({
            method: "convert",
            type: "base64",
            value: value,
            isEncode: false
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @returns {ArrayBuffer}
     */
    md5: (value) => {
        return sendMessage({
            method: "convert",
            type: "md5",
            value: value,
            isEncode: true
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @returns {ArrayBuffer}
     */
    sha1: (value) => {
        return sendMessage({
            method: "convert",
            type: "sha1",
            value: value,
            isEncode: true
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @returns {ArrayBuffer}
     */
    sha256: (value) => {
        return sendMessage({
            method: "convert",
            type: "sha256",
            value: value,
            isEncode: true
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @returns {ArrayBuffer}
     */
    sha512: (value) => {
        return sendMessage({
            method: "convert",
            type: "sha512",
            value: value,
            isEncode: true
        });
    },

    /**
     * @param key {ArrayBuffer}
     * @param value {ArrayBuffer}
     * @param hash {string} - md5, sha1, sha256, sha512
     * @returns {ArrayBuffer}
     */
    hmac: (key, value, hash) => {
        return sendMessage({
            method: "convert",
            type: "hmac",
            value: value,
            key: key,
            hash: hash,
            isEncode: true
        });
    },

    /**
     * @param key {ArrayBuffer}
     * @param value {ArrayBuffer}
     * @param hash {string} - md5, sha1, sha256, sha512
     * @returns {string} - hex string
     */
    hmacString: (key, value, hash) => {
        return sendMessage({
            method: "convert",
            type: "hmac",
            value: value,
            key: key,
            hash: hash,
            isEncode: true,
            isString: true
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @returns {ArrayBuffer}
     */
    encryptAesEcb: (value, key) => {
        return sendMessage({
            method: "convert",
            type: "aes-ecb",
            value: value,
            key: key,
            isEncode: true
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @returns {ArrayBuffer}
     */
    decryptAesEcb: (value, key) => {
        return sendMessage({
            method: "convert",
            type: "aes-ecb",
            value: value,
            key: key,
            isEncode: false
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @param {ArrayBuffer} iv
     * @returns {ArrayBuffer}
     */
    encryptAesCbc: (value, key, iv) => {
        return sendMessage({
            method: "convert",
            type: "aes-cbc",
            value: value,
            key: key,
            iv: iv,
            isEncode: true
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @param {ArrayBuffer} iv
     * @returns {ArrayBuffer}
     */
    decryptAesCbc: (value, key, iv) => {
        return sendMessage({
            method: "convert",
            type: "aes-cbc",
            value: value,
            key: key,
            iv: iv,
            isEncode: false
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @param {ArrayBuffer} iv
     * @param {number} blockSize
     * @returns {ArrayBuffer}
     */
    encryptAesCfb: (value, key, iv, blockSize) => {
        return sendMessage({
            method: "convert",
            type: "aes-cfb",
            value: value,
            key: key,
            iv: iv,
            blockSize: blockSize,
            isEncode: true
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @param {ArrayBuffer} iv
     * @param {number} blockSize
     * @returns {ArrayBuffer}
     */
    decryptAesCfb: (value, key, iv, blockSize) => {
        return sendMessage({
            method: "convert",
            type: "aes-cfb",
            value: value,
            key: key,
            iv: iv,
            blockSize: blockSize,
            isEncode: false
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @param {number} blockSize
     * @returns {ArrayBuffer}
     */
    encryptAesOfb: (value, key, blockSize) => {
        return sendMessage({
            method: "convert",
            type: "aes-ofb",
            value: value,
            key: key,
            blockSize: blockSize,
            isEncode: true
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @param {number} blockSize
     * @returns {ArrayBuffer}
     */
    decryptAesOfb: (value, key, blockSize) => {
        return sendMessage({
            method: "convert",
            type: "aes-ofb",
            value: value,
            key: key,
            blockSize: blockSize,
            isEncode: false
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @returns {ArrayBuffer}
     */
    decryptRsa: (value, key) => {
        return sendMessage({
            method: "convert",
            type: "rsa",
            value: value,
            key: key,
            isEncode: false
        });
    },
    /** Encode bytes to hex string
     * @param bytes {ArrayBuffer}
     * @return {string}
     */
    hexEncode: (bytes) => {
        const hexDigits = '0123456789abcdef';
        const view = new Uint8Array(bytes);
        let charCodes = new Uint8Array(view.length * 2);
        let j = 0;

        for (let i = 0; i < view.length; i++) {
            let byte = view[i];
            charCodes[j++] = hexDigits.charCodeAt((byte >> 4) & 0xF);
            charCodes[j++] = hexDigits.charCodeAt(byte & 0xF);
        }

        return String.fromCharCode(...charCodes);
    },
}

class _Timer {
    delay = 0;

    callback = () => { };

    status = false;

    constructor(delay, callback) {
        this.delay = delay;
        this.callback = callback;
    }

    run() {
        this.status = true;
        this._interval();
    }

    _interval() {
        if (!this.status) {
            return;
        }
        this.callback();
        setTimeout(this._interval.bind(this), this.delay);
    }

    cancel() {
        this.status = false;
    }
}

globalThis.setInterval = function setInterval(callback, delay) {
    let timer = new _Timer(delay, callback);
    timer.run();
    return timer;
};

/**
 * Network object for sending HTTP requests.
 * @namespace Network
 */
let Network = {
    /**
     * Sends an HTTP request.
     * @param {string} method - The HTTP method (e.g., GET, POST, PUT, PATCH, DELETE).
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @param {Object} extra - Extra options to pass to the interceptor.
     * @returns {Promise<{status: number, headers: {}, body: ArrayBuffer}>} The response from the request.
     */
    async fetchBytes(method, url, headers, data, extra) {
        let result = await sendMessage({
            method: 'http',
            http_method: method,
            bytes: true,
            url: url,
            headers: headers,
            data: data,
            extra: extra,
        });

        if (result.error) {
            throw result.error;
        }

        return result;
    },

    /**
     * Sends an HTTP request.
     * @param {string} method - The HTTP method (e.g., GET, POST, PUT, PATCH, DELETE).
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @param {Object} extra - Extra options to pass to the interceptor.
     * @returns {Promise<{status: number, headers: {}, body: string}>} The response from the request.
     */
    async sendRequest(method, url, headers, data, extra) {
        let result = await sendMessage({
            method: 'http',
            http_method: method,
            url: url,
            headers: headers,
            data: data,
            extra: extra,
        });

        if (result.error) {
            throw result.error;
        }

        return result;
    },

    /**
     * Sends an HTTP GET request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param {Object} extra - Extra options to pass to the interceptor.
     * @returns {Promise<{status: number, headers: {}, body: string}>} The response from the request.
     */
    async get(url, headers, extra) {
        return this.sendRequest('GET', url, headers, null, extra);
    },

    /**
     * Sends an HTTP POST request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @param {Object} extra - Extra options to pass to the interceptor.
     * @returns {Promise<{status: number, headers: {}, body: string}>} The response from the request.
     */
    async post(url, headers, data, extra) {
        return this.sendRequest('POST', url, headers, data, extra);
    },

    /**
     * Sends an HTTP PUT request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @param {Object} extra - Extra options to pass to the interceptor.
     * @returns {Promise<{status: number, headers: {}, body: string}>} The response from the request.
     */
    async put(url, headers, data, extra) {
        return this.sendRequest('PUT', url, headers, data, extra);
    },

    /**
     * Sends an HTTP PATCH request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @param {Object} extra - Extra options to pass to the interceptor.
     * @returns {Promise<{status: number, headers: {}, body: string}>} The response from the request.
     */
    async patch(url, headers, data, extra) {
        return this.sendRequest('PATCH', url, headers, data, extra);
    },

    /**
     * Sends an HTTP DELETE request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param {Object} extra - Extra options to pass to the interceptor.
     * @returns {Promise<{status: number, headers: {}, body: string}>} The response from the request.
     */
    async delete(url, headers, extra) {
        return this.sendRequest('DELETE', url, headers, null, extra);
    },
};

/**
 * HtmlDocument class for parsing HTML and querying elements.
 */
class HtmlDocument {
    static _key = 0;

    key = 0;

    /**
     * Constructor for HtmlDocument.
     * @param {string} html - The HTML string to parse.
     */
    constructor(html) {
        this.key = HtmlDocument._key;
        HtmlDocument._key++;
        sendMessage({
            method: "html",
            function: "parse",
            key: this.key,
            data: html
        })
    }

    /**
     * Query a single element from the HTML document.
     * @param {string} query - The query string.
     * @returns {HtmlElement | null} The first matching element.
     */
    querySelector(query) {
        let k = sendMessage({
            method: "html",
            function: "querySelector",
            key: this.key,
            query: query
        })
        if(k == null) return null;
        return new HtmlElement(k, this.key);
    }

    /**
     * Query all matching elements from the HTML document.
     * @param {string} query - The query string.
     * @returns {HtmlElement[]} An array of matching elements.
     */
    querySelectorAll(query) {
        let ks = sendMessage({
            method: "html",
            function: "querySelectorAll",
            key: this.key,
            query: query
        })
        return ks.map(k => new HtmlElement(k, this.key));
    }

    /**
     * Dispose the HTML document.
     * This should be called when the document is no longer needed.
     */
    dispose() {
        sendMessage({
            method: "html",
            function: "dispose",
            key: this.key
        })
    }

    /**
     * Get the element by its id.
     * @param id {string}
     * @returns {HtmlElement|null}
     */
    getElementById(id) {
        let k = sendMessage({
            method: "html",
            function: "getElementById",
            key: this.key,
            id: id
        })
        if(k == null) return null;
        return new HtmlElement(k, this.key);
    }
}

/**
 * HtmlDom class for interacting with HTML elements.
 */
class HtmlElement {
    key = 0;

    doc = 0;

    /**
     * Constructor for HtmlDom.
     * @param {number} k - The key of the element.
     * @param {number} doc - The key of the document.
     */
    constructor(k, doc) {
        this.key = k;
        this.doc = doc;
    }

    /**
     * Get the text content of the element.
     * @returns {string} The text content.
     */
    get text() {
        return sendMessage({
            method: "html",
            function: "getText",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Get the attributes of the element.
     * @returns {Object} The attributes.
     */
    get attributes() {
        return sendMessage({
            method: "html",
            function: "getAttributes",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Query a single element from the current element.
     * @param {string} query - The query string.
     * @returns {HtmlElement} The first matching element.
     */
    querySelector(query) {
        let k = sendMessage({
            method: "html",
            function: "dom_querySelector",
            key: this.key,
            query: query,
            doc: this.doc,
        })
        if(k == null) return null;
        return new HtmlElement(k, this.doc);
    }

    /**
     * Query all matching elements from the current element.
     * @param {string} query - The query string.
     * @returns {HtmlElement[]} An array of matching elements.
     */
    querySelectorAll(query) {
        let ks = sendMessage({
            method: "html",
            function: "dom_querySelectorAll",
            key: this.key,
            query: query,
            doc: this.doc,
        })
        return ks.map(k => new HtmlElement(k, this.doc));
    }

    /**
     * Get the children of the current element.
     * @returns {HtmlElement[]} An array of child elements.
     */
    get children() {
        let ks = sendMessage({
            method: "html",
            function: "getChildren",
            key: this.key,
            doc: this.doc,
        })
        return ks.map(k => new HtmlElement(k, this.doc));
    }

    /**
     * Get the nodes of the current element.
     * @returns {HtmlNode[]} An array of nodes.
     */
    get nodes() {
        let ks = sendMessage({
            method: "html",
            function: "getNodes",
            key: this.key,
            doc: this.doc,
        })
        return ks.map(k => new HtmlNode(k, this.doc));
    }

    /**
     * Get inner HTML of the element.
     * @returns {string} The inner HTML.
     */
    get innerHTML() {
        return sendMessage({
            method: "html",
            function: "getInnerHTML",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Get parent element of the element. If the element has no parent, return null.
     * @returns {HtmlElement|null}
     */
    get parent() {
        let k = sendMessage({
            method: "html",
            function: "getParent",
            key: this.key,
            doc: this.doc,
        })
        if(k == null) return null;
        return new HtmlElement(k, this.doc);
    }

    /**
     * Get class names of the element.
     * @returns {string[]} An array of class names.
     */
    get classNames() {
        return sendMessage({
            method: "html",
            function: "getClassNames",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Get id of the element.
     * @returns {string | null} The id of the element.
     */
    get id() {
        return sendMessage({
            method: "html",
            function: "getId",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Get local name of the element.
     * @returns {string} The tag name of the element.
     */
    get localName() {
        return sendMessage({
            method: "html",
            function: "getLocalName",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Get the previous sibling element of the element. If the element has no previous sibling, return null.
     * @returns {HtmlElement|null}
     */
    get previousElementSibling() {
        let k = sendMessage({
            method: "html",
            function: "getPreviousSibling",
            key: this.key,
            doc: this.doc,
        })
        if(k == null) return null;
        return new HtmlElement(k, this.doc);
    }

    /**
     * Get the next sibling element of the element. If the element has no next sibling, return null.
     * @returns {HtmlElement|null}
     */
    get nextElementSibling() {
        let k = sendMessage({
            method: "html",
            function: "getNextSibling",
            key: this.key,
            doc: this.doc,
        })
        if (k == null) return null;
        return new HtmlElement(k, this.doc);
    }
}

class HtmlNode {
    key = 0;

    doc = 0;

    constructor(k, doc) {
        this.key = k;
        this.doc = doc;
    }

    /**
     * Get the text content of the node.
     * @returns {string} The text content.
     */
    get text() {
        return sendMessage({
            method: "html",
            function: "node_text",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Get the type of the node.
     * @returns {string} The type of the node. ("text", "element", "comment", "document", "unknown")
     */
    get type() {
        return sendMessage({
            method: "html",
            function: "node_type",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Convert the node to an HtmlElement. If the node is not an element, return null.
     * @returns {HtmlElement|null}
     */
    toElement() {
        let k = sendMessage({
            method: "html",
            function: "node_toElement",
            key: this.key,
            doc: this.doc,
        })
        if(k == null) return null;
        return new HtmlElement(k, this.doc);
    }
}

function log(level, title, content) {
    sendMessage({
        method: 'log',
        level: level,
        title: title,
        content: content,
    })
}

globalThis.console = {
    log: (content) => {
        log('info', 'JS Console', content)
    },
    warn: (content) => {
        log('warning', 'JS Console', content)
    },
    error: (content) => {
        log('error', 'JS Console', content)
    },
};

function getLocale() {
    return sendMessage({
        method: 'getLocale'
    });
}

// Hazuki.translate 与 HazukiSource.translate 共用的语言映射与翻译表解析规则。
function localizeText(text, translation = {}, locale = getLocale()) {
    let normalized = locale.replace(/-/g, '_');
    const language = normalized.split('_')[0];
    if (normalized === language) {
        normalized = language === 'zh' ? 'zh_CN' : language === 'en' ? 'en_US' : language;
    }
    const keys = [normalized, normalized.replace(/_/g, '-')];
    keys.push(language);
    const validText = value => typeof value === 'string' && value.trim().length > 0;
    if (text && typeof text === 'object') {
        for (const key of [...keys, 'en_US', 'en-US', 'en']) {
            if (validText(text[key])) return text[key];
        }
        return Object.values(text).find(validText) ?? '';
    }
    const original = text == null ? '' : String(text);
    for (const key of keys) {
        const value = translation?.[key]?.[original.trim()];
        if (validText(value)) return value;
    }
    return original;
}

// 仅供紧随其后的 SDK 读取；SDK 取走后立即删除，插件脚本无法访问。
globalThis.__hazukiRuntime = Object.freeze({
    Network,
    Convert,
    HtmlDocument,
    getLocale,
    localizeText,
});
})();
