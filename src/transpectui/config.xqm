module namespace config = 'http://le-tex.de/config';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';

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
      $context?title
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
    attribute class {'d-flex'},
    element a {
      attribute href {config:url('/' || $context?lang || $context?url)},
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
    }
  }
}; 

declare function config:url($url) {
  $config:base-url || $url
};