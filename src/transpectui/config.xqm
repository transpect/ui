module namespace config = 'http://le-tex.de/config';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';

declare variable $config:file := doc('config.xml');
declare variable $config:data-dir-base := $config:file/configurations/configuration/data-dir-base/text();
declare variable $config:base-url := $config:file/configurations/configuration/base-url/text();

declare function config:get-html-head($context) {
  element head {
    element meta{
      attribute http-equiv {'refresh'},
      attribute content {$context?refresh}
    }[$context?refresh gt 0],
    element title {
      $context?status || $context?title
    },
    element link {
      attribute rel {"stylesheet"},
      attribute type {"text/css"},
      attribute href {config:url("/static/transpectui.css")}
    },
    element link{
      attribute rel {"icon"},
      attribute type {"image/x-icon"},
      attribute href {config:url("/static/favicon-96x96.png")}
    },
    element script {
      attribute src {config:url("/static/transpectui.js")}
    }
  }
}; 

declare function config:get-html-header($context as map(xs:string, item()?)) {
  element header {
    attribute class {'d-flex column'},
    element div {
    attribute class {'d-flex'},
      element a {
        attribute href {config:url('/' || $context?lang || $context?return-url)},
        element img {
          attribute class {"header"},
          attribute src {config:url("/static/transpect.png")}
        }
      },
      element div {
        attribute class {'d-flex center'},
        element h1 {$context?title},
        if ($context?subtitle) then element span {attribute class {'date'}, '(' || $context?subtitle || ')'}
      },
      element div {
      attribute class {'d-flex center'},
        element ul {
          for $language in $i18n:languages//language
          return (
            element a {
              attribute href {config:url("/" || $language/xs:string(@short) || $context?url)},
              element img {
                attribute class {'lang-img'},
                attribute src {config:url('/static/' || $language/xs:string(@short) ||'.png')}
              }
            }
          )
        },
        if (session:get('username'))
        then 
          element div {
            attribute class {'d-flex column'},
            attribute style {'margin-top: -5px;'},
            hf:create-anchor(config:url('/' || $context?lang || '/users/'|| session:get('username') || '?url=' || config:url($context?url)),session:get('username'),'lang-img'),
            hf:create-anchor(config:url('/' || $context?lang || '/logout?url=' || config:url('/' || $context?lang || $context?url)),i18n:static-replacement('logout', $context?lang),'lang-img')
          }
        else hf:create-anchor(config:url('/' || $context?lang || '/login?url=' || config:url('/' || $context?lang || $context?url)),i18n:static-replacement('login', $context?lang),'lang-img')
      }
    },
    element div {
      attribute class {'breadcrumbs'},
      let $parts := $context?url => tokenize('/')
      return 
        for $part at $i in $parts[normalize-space(.)][position() ne last()]
        return element span {hf:create-anchor(config:url(('/' || $context?lang, string-join($parts[position() le $i + 1],'/'))),$part)}
    }
  }
}; 

declare function config:url($url) {
  $config:base-url || $url
};