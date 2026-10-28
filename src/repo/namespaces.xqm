module namespace ns = 'http://le-tex.de/namespaces';
(: 
 : all used module import statements to use in job:eval statements.
 :)
declare variable $ns:api    := "import module namespace api = 'http://le-tex.de/api' at '/opt/basex/webapp/transpectui/api.xqm';";
declare variable $ns:data   := "import module namespace data = 'http://le-tex.de/data' at '/opt/basex/webapp/transpectui/data.xqm';";
declare variable $ns:ui     := "import module namespace ui = 'http://le-tex.de/transpectui' at '/opt/basex/webapp/transpectui/transpectui.xqm';";

declare variable $ns:conv   := "import module namespace conv = 'http://le-tex.de/converter' at '/opt/basex/install/transpectui/converter.xqm';";
declare variable $ns:config := "import module namespace config = 'http://le-tex.de/config' at '/opt/basex/install/transpectui/config.xqm';";
declare variable $ns:hf     := "import module namespace hf = 'http://le-tex.de/helper-functions' at '/opt/basex/install/transpectui/helper-functions.xqm';";
declare variable $ns:i18n   := "import module namespace i18n = 'http://le-tex.de/i18n' at '/opt/basex/install/transpectui/i18n.xqm';";
declare variable $ns:make   := "import module namespace make = 'http://le-tex.de/make' at '/opt/basex/install/transpectui/make.xqm';";
declare variable $ns:store  := "import module namespace st = 'http://le-tex.de/store' at '/opt/basex/install/transpectui/store.xqm';";
declare variable $ns:ns     := "import module namespace ns = 'http://le-tex.de/namespaces' at '/opt/basex/install/transpectui/namespaces.xqm';";
declare variable $ns:user   := "import module namespace u = 'http://le-tex.de/user' at '/opt/basex/install/transpectui/user.xqm';";
declare variable $ns:queue  := "import module namespace queue = 'http://le-tex.de/queue' at '/opt/basex/install/transpectui/queue.xqm';";
declare variable $ns:tr     := "import module namespace tr = 'http://le-tex.de/transpect' at '/opt/basex/install/transpectui/transpect.xqm';";
declare variable $ns:worker := "import module namespace worker = 'http://le-tex.de/worker' at '/opt/basex/install/transpectui/worker.xqm';";

declare function ns:install() {
  for $ns in ($ns:conv, $ns:config, $ns:hf, $ns:i18n, $ns:make, $ns:store, $ns:ns, $ns:user, $ns:queue, $ns:tr, $ns:worker)
  return repo:install($ns => replace(".* at '|';",''))
};