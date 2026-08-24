module namespace tr  = 'http://le-tex.de/transpect';
import module namespace u = 'http://le-tex.de/user' at 'user.xqm';
import module namespace worker = 'http://le-tex.de/worker' at 'worker.xqm';
import module namespace conv = 'http://le-tex.de/converter' at 'converter.xqm';

declare variable $tr:rights-map :=
  map {
    '^(/[^/]+)?/worker$':'worker:list',
    '^(/[^/]+)?/worker/([^/]+)$':'$2:list',
    '^(/[^/]+)?/worker/([^/]+)/converter$':'$2:list',
    '^(/[^/]+)?/worker/([^/]+)/converter/([^/]+)$':'$2-$3:default',
    '^(/[^/]+)?/worker/([^/]+)/converter/([^/]+)/runs$':'$2-$3:default',
    '^(/[^/]+)?/worker/([^/]+)/converter/([^/]+)/convert$':'$2-$3:convert',
    '^(/[^/]+)?/converter$':'tr:list',
    '^(/[^/]+)?/converter/([^/]+)$':'$2:default',
    '^(/[^/]+)?/converter/([^/]+)/runs$':'$2:default',
    '^(/[^/]+)?/converter/([^/]+)/convert$':'$2:convert',
    '^(/[^/]+)?/users$':'u:mgmt',
    '^(/[^/]+)?/users/([^/]+)$':'u:mgmt'
  };
  
declare variable $tr:owner-map :=
  map {
    '^(/[^/]+)?/users/([^/]+)$':'$2'
  };

declare function tr:endpoint-right($url as xs:string?) as xs:string* {
  let $matching :=  
        for $regex in map:keys($tr:rights-map)
        where matches($url, $regex)
        return replace($url,$regex,$tr:rights-map?$regex)
  return $matching
};

declare function tr:endpoint-owner($url as xs:string?) as xs:string* {
  let $matching :=  
        for $regex in map:keys($tr:owner-map)
        where matches($url, $regex)
        return replace($url,$regex,$tr:owner-map?$regex)
  return $matching
};

declare variable $tr:dynamic-worker-roles :=
  for $w in $worker:worker
  let $converters := worker:converter($w)
  return 
    for $c in $converters
    return 
      for $r in (map {'role':'default', 'name': 'convert,default'},map {'role':'runs', 'name': 'conversions,default'},map {'role':'admin', 'matches': ''})
      return
        element role {
          attribute name {$c/@worker || '-' || $c/@id || ':' || $r?role},
          for $name in tokenize($r?name,',') return 
          element right {
            attribute name {$c/@worker || '-' || $c/@id || ':' || $name}[map:keys($r) = 'name']
          }[map:keys($r) = 'name'],
          element right {
            attribute matches {$c/@worker || '-' || $c/@id || ':' || $r?name}
          }[map:keys($r) = 'matches']
        };
        
declare variable $tr:dynamic-local-roles :=
  for $c in $conv:converters
  return
    for $r in (map {'role':'default', 'name': 'convert,default'},map {'role':'runs', 'name': 'conversions'},map {'role':'admin', 'matches': ''})
    return
      element role {
          attribute name {$c/@id || ':' || $r?role},
          for $name in tokenize($r?name,',') return 
          element right {
            attribute name {$c/@id || ':' || $name}
          }[map:keys($r) = 'name'],
          element right {
            attribute matches {$c/@id || ':' || $r?name}
          }[map:keys($r) = 'matches']
        };
        
declare variable $tr:dynamic-roles := ($tr:dynamic-worker-roles, $tr:dynamic-local-roles);

declare function tr:check($username as xs:string?, $token as xs:string?, $right as xs:string?, $owner as xs:string? := ()) {
  let $is-valid := u:validate-token($username, $token),
      $is-allowed := if ($is-valid) then u:check($username, $token, $right, $owner, $tr:dynamic-roles) else false()
  return $is-allowed
};

declare function tr:can-do($username as xs:string?, $right as xs:string?, $owner as xs:string? := ()) {
  u:can-do(u:users($username), $right, $tr:dynamic-roles, $owner)
};

declare function tr:roles() {
  let $static-roles := u:roles()
  return $static-roles update {insert nodes ($tr:dynamic-roles) into .}
};

declare function tr:roles-for-right($right as xs:string?) as xs:string* {
  if (exists($right))
  then
    for $role in ($tr:dynamic-roles,u:roles()/role)
    where (matches($right,$role/right/@matches)[exists($role/right/@matches)] or $role/right/@name[$right eq .])
    return $role/@name
};