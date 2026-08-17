module namespace tr  = 'http://le-tex.de/transpect';
import module namespace u = 'http://le-tex.de/user' at 'user.xqm';
import module namespace worker = 'http://le-tex.de/worker' at 'worker.xqm';
import module namespace conv = 'http://le-tex.de/converter' at 'converter.xqm';

declare variable $tr:dynamic-worker-roles :=
  for $w in $worker:worker
  let $converters := worker:converter($w)
  return 
    for $c in $converters
    return 
      for $r in (map {'role':'default', 'name': 'convert'},map {'role':'runs', 'name': 'conversions'},map {'role':'admin', 'matches': ''})
      return
        element role {
          attribute name {$c/@worker || '-' || $c/@id || ':' || $r?role},
          element right {
            attribute name {$c/@worker || '-' || $c/@id || ':' || $r?name}[map:keys($r) = 'name'],
            attribute matches {$c/@worker || '-' || $c/@id || ':' || $r?name}[map:keys($r) = 'matches']
          }
        };
declare variable $tr:dynamic-local-roles :=
  for $c in $conv:converters
  return
    for $r in (map {'role':'default', 'name': 'convert'},map {'role':'runs', 'name': 'conversions'},map {'role':'admin', 'matches': ''})
    return
      element role {
        attribute name {$c/@id || ':' || $r?role}, 
        element right {
          attribute name {$c/@id || ':' || $r?name}[map:keys($r) = 'name'],
          attribute matches {$c/@id || ':' || $r?name}[map:keys($r) = 'matches']
        }
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