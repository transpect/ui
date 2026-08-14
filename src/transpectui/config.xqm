module namespace config = 'http://le-tex.de/config';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';

declare variable $config:file := doc('config.xml');
declare variable $config:data-dir-base := $config:file/configurations/configuration/data-dir-base/text();
declare variable $config:base-url := $config:file/configurations/configuration/base-url/text();

declare function config:url($url) {
  $config:base-url || $url
};