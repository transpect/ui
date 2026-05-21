module namespace st = 'http://le-tex.de/store';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';

declare variable $st:type := 'file';
(: 
 : wrapper module for basex store access
 :)

declare function st:set($prefix, $runid, $value){
  if (not(file:exists("/opt/data/runs/" || $runid))) then file:create-dir("/opt/data/runs/" || $runid) else (),
  hf:log($prefix || ':' || $runid || ' set to ' || string-join($value ! xs:string(.),', ')),
  switch ($st:type)
    case 'store' return store:put($prefix || ':' || $runid, $value)
    case 'file' return 
      if ($value instance of element()) 
      then file:write("/opt/data/runs/" || $runid || '/' || $prefix,$value)
      else file:write-text-lines("/opt/data/runs/" || $runid || '/' || $prefix, $value ! xs:string(.))
    default return ()
};

declare function st:get($prefix, $runid){
  let $file := "/opt/data/runs/" || $runid || '/' || $prefix
  return
    switch ($st:type)
      case 'store' return store:get($prefix || ':' || $runid)
      case 'file' return 
        let $text := if (file:exists($file)) then file:read-text($file) else (),
            $parse := 
              try {
                parse-xml($text)
              } catch * {
                $text ! tokenize(.,'\n')[normalize-space(.)]
              }
        return $parse
      default return ()
};

declare function st:get-runs() as xs:string* {
  switch ($st:type)
    case 'store' return store:keys()[matches(.,'^start:')] ! tokenize(.,':')[2]
    case 'file' return
      let $runids := file:list("/opt/data/runs")
      return
        for $runid in $runids
        let $file := st:get('file',$runid),
            $file-exists := if ($file) then file:exists($file)
        where $file-exists 
        return $runid
    default return ()
};