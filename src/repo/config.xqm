module namespace config = 'http://le-tex.de/config';

declare variable $config:file := doc("/opt/basex/install/transpectui/config.xml");
declare variable $config:data-dir-base := $config:file/configurations/configuration/data-dir-base/text();
declare variable $config:base-url := $config:file/configurations/configuration/base-url/text();

declare function config:url($url) {
  $config:base-url || $url
};