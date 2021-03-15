var randomEventName = "adblock-event-" + Math.random().toString(36).substr(2);

function injected(eventName)
{
    window.eventName = eventName;
};

var localeMessages = {};

function runInPageContext(fnString, arg)
{
    let script = document.createElement("script");
    script.type = "application/javascript";
    script.async = false;
    script.textContent = "(" + fnString + ")(" + JSON.stringify(arg) + ");";
    document.documentElement.appendChild(script);
    document.documentElement.removeChild(script);
}

function addCSSToInPageContext(cssString)
{
    let style = document.createElement("style");
    style.classList.add("adblock-ui-stylesheet");
    style.textContent = cssString;
    document.documentElement.appendChild(style);
}

function handleMessage(event) {
    if (event.message && event.message.evalScript && event.message.topOnly && (window.top === window.self)) {
        try {
            eval(event.message.evalScript);
        } catch(err) {
            console.error(err)
            console.error(event.message.evalScript)
        }
    } else if (event.message && event.message.addCSS && event.message.topOnly && (window.top === window.self)) {
        addCSSToInPageContext(event.message.addCSS);
    } else if (event.message && event.message.localeMessages && event.message.topOnly && (window.top === window.self)) {
        localeMessages = JSON.parse(event.message.localeMessages);
    }
}

safari.self.addEventListener("message", handleMessage);

var randomEventListener = event => {
  safari.extension.dispatchMessage("whitelist_ui_event", event.detail);
};

document.addEventListener(randomEventName, randomEventListener);

// Insert substitution args into a localized string.
function parseString(msgData, args) {
    // If no substitution, just turn $$ into $ and short-circuit.
    if (msgData.placeholders == undefined && args == undefined)
        return msgData.message.replace(/\$\$/g, '$');

    // Substitute a regex while understanding that $$ should be untouched
    function safesub(txt, re, replacement) {
        var dollaRegex = /\$\$/g, dollaSub = "~~~I18N~~:";
        txt = txt.replace(dollaRegex, dollaSub);
        txt = txt.replace(re, replacement);
        // Put back in "$$" ("$$$$" somehow escapes down to "$$")
        var undollaRegex = /~~~I18N~~:/g, undollaSub = "$$$$";
        txt = txt.replace(undollaRegex, undollaSub);
        return txt;
    }

    var $n_re = /\$([1-9])/g;
    var $n_subber = function(_, num) { return args[num - 1]; };

    var placeholders = {};
    // Fill in $N in placeholders
    for (var name in msgData.placeholders) {
        var content = msgData.placeholders[name].content;
        placeholders[name.toLowerCase()] = safesub(content, $n_re, $n_subber);
    }
    // Fill in $N in message
    var message = safesub(msgData.message, $n_re, $n_subber);
    // Fill in $Place_Holder1$ in message
    message = safesub(message, /\$(\w+?)\$/g, function(full, name) {
                      var lowered = name.toLowerCase();
                      if (lowered in placeholders)
                      return placeholders[lowered];
                      return full; // e.g. '$FoO$' instead of 'foo'
                      });
    // Replace $$ with $
    message = message.replace(/\$\$/g, '$');

    return message;
}


var translate = function (messageID, args) {
    if (Array.isArray(args)) {
        for (var i = 0; i < args.length; i++) {
            if (typeof args[i] !== 'string') {
                args[i] = args[i].toString();
            }
        }
    } else if (args && typeof args !== 'string') {
        args = args.toString();
    }

    if (localeMessages && messageID in localeMessages) {
        return parseString(localeMessages[messageID], args);
    }
};

// Determine what language the user's browser is set to use
var determineUserLanguage = function () {
    if ((typeof navigator.language !== 'undefined') &&
        navigator.language)
        return navigator.language.match(/^[a-z]+/i)[0];
    else
        return null;
};

// Parse a URL. Based upon http://blog.stevenlevithan.com/archives/parseuri
// parseUri 1.2.2, (c) Steven Levithan <stevenlevithan.com>, MIT License
// Inputs: url: the URL you want to parse
// Outputs: object containing all parts of |url| as attributes
var parseUri = function (url) {
    var matches = /^(([^:]+(?::|$))(?:(?:\w+:)?\/\/)?(?:[^:@\/]*(?::[^:@\/]*)?@)?(([^:\/?#]*)(?::(\d*))?))((?:[^?#\/]*\/)*[^?#]*)(\?[^#]*)?(\#.*)?/.exec(url);

    // The key values are identical to the JS location object values for that key
    var keys = ['href', 'origin', 'protocol', 'host', 'hostname', 'port',
                'pathname', 'search', 'hash',];
    var uri = {};
    for (var i = 0; (matches && i < keys.length); i++)
        uri[keys[i]] = matches[i] || '';
    return uri;
};

// Parses the search part of a URL into an key: value object.
// e.g., ?hello=world&ext=adblock would become {hello:"world", ext:"adblock"}
// Inputs: search: the search query of a URL. Must have &-separated values.
parseUri.parseSearch = function (search) {

    // Fails if a key exists twice (e.g., ?a=foo&a=bar would return {a:"bar"}
    search = search.substring(search.indexOf('?') + 1).split('&');
    var params = {}, pair;
    for (var i = 0; i < search.length; i++) {
        pair = search[i].split('=');
        if (pair[0] && !pair[1])
            pair[1] = '';
        if (!params[decodeURIComponent(pair[0])] && decodeURIComponent(pair[1]) === 'undefined') {
            continue;
        } else {
            params[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1]);
        }
    }

    return params;
};

// Strip third+ level domain names from the domain and return the result.
// Inputs: domain: the domain that should be parsed
//         keepDot: true if trailing dots should be preserved in the domain
// Returns: the parsed domain
parseUri.secondLevelDomainOnly = function (domain, keepDot) {
    var match = domain.match(/([^\.]+\.(?:co\.)?[^\.]+)\.?$/) || [domain, domain];
    return match[keepDot ? 0 : 1].toLowerCase();
};
