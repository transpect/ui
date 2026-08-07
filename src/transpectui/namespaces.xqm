module namespace ns = 'http://le-tex.de/namespaces';
(: 
 : all used module import statements to use in job:eval statements.
 :)
declare variable $ns:api   := "import module namespace api = 'http://le-tex.de/api' at '/opt/basex/webapp/transpectui/api.xqm';";
declare variable $ns:conv  := "import module namespace conv = 'http://le-tex.de/converter' at '/opt/basex/webapp/transpectui/converter.xqm';";
declare variable $ns:config:= "import module namespace config = 'http://le-tex.de/config' at '/opt/basex/webapp/transpectui/config.xqm';";
declare variable $ns:hf    := "import module namespace hf = 'http://le-tex.de/helper-functions' at '/opt/basex/webapp/transpectui/helper-functions.xqm';";
declare variable $ns:i18n  := "import module namespace i18n = 'http://le-tex.de/i18n' at '/opt/basex/webapp/transpectui/i18n.xqm';";
declare variable $ns:make  := "import module namespace make = 'http://le-tex.de/make' at '/opt/basex/webapp/transpectui/make.xqm';";
declare variable $ns:store := "import module namespace st = 'http://le-tex.de/store' at '/opt/basex/webapp/transpectui/store.xqm';";
declare variable $ns:ns    := "import module namespace ns = 'http://le-tex.de/namespaces' at '/opt/basex/webapp/transpectui/namespaces.xqm';";
declare variable $ns:data  := "import module namespace data = 'http://le-tex.de/data' at '/opt/basex/webapp/transpectui/data.xqm';";
declare variable $ns:user  := "import module namespace u = 'http://le-tex.de/user' at '/opt/basex/webapp/transpectui/user.xqm';";
declare variable $ns:queue := "import module namespace queue = 'http://le-tex.de/queue' at '/opt/basex/webapp/transpectui/queue.xqm';";
declare variable $ns:ui    := "import module namespace ui = 'http://le-tex.de/transpectui' at '/opt/basex/webapp/transpectui/transpectui.xqm';";

declare function ns:install() {
  for $ns in ($ns:api, $ns:conv, $ns:config, $ns:hf, $ns:i18n, $ns:make, $ns:store, $ns:ns, $ns:data, $ns:user, $ns:queue, $ns:ui)
  return repo:install($ns => replace(".* at '|';",''))
};