module namespace u = 'http://le-tex.de/user';

(: 
 : module for user management in BaseX circumventing the default user management
 : - roles are used to appache rights to them
 : - groups are to be used in the application for users to share information
 :)

declare variable $u:token-max-age := 3600000;
declare variable $u:users-file := '/opt/basex/webapp/transpectui/users.xml';
declare variable $u:roles-file := '/opt/basex/webapp/transpectui/roles.xml';
declare variable $u:default-roles := 
  <roles>
    <role name="admin">
      <right matches="."></right>
    </role>
    <role name="u:mgmt">
      <right matches="u:"></right>
    </role>
  </roles>;
  
declare variable $u:default-users :=
  <users>
    <user source="default">
      <username>admin</username>
      <roles>
        <role name="admin"></role>
      </roles>
    </user>
  </users>;

(:
 : match based on username
 :)
 
declare %private function u:merge($users-default as element(users)*,$users-file as element(users)*) {
  let $names := distinct-values(($users-default,$users-file)/user/username/text())
  return
    element users {
      for $name in $names
      let $user-base := $users-default/user[username eq $name],
          $user-top := $users-file/user[username eq $name]
      return
        if ($user-base/username/text() ne $user-top/username/text())
        then element error { attribute code {'400'}, 'Usernames are not equal'}
        else 
          element user {
            attribute source {
              if (exists($user-base) and exists($user-top))
              then 'merged'
              else
                if (exists($user-base)) 
                then 'default' 
                else 'file'},
            element username {$name},
            ($user-top/password,$user-base/password)[1],
            ($user-top/salt,$user-base/salt)[1],
            element roles {$user-top/roles/role,$user-base/roles/role}
          }
    }
};

declare function u:users(){
  u:users-int() update {delete node .//password, delete node .//salt}
};

declare function u:users($username as xs:string?){
  u:users-int($username) update {delete node .//password, delete node .//salt}
};

declare %private function u:users-int(){
  u:merge(
    $u:default-users,
    if (file:exists($u:users-file)) then doc($u:users-file)/users
  )
};

declare %private function u:users-int($username as xs:string?) as element(user)? {
  if ($username) then u:users-int()/user[username eq $username] else ()
};

 declare function u:roles(){
  if (file:exists($u:roles-file)) then (doc($u:roles-file)/roles update {insert node $u:default-roles/role into .}) else $u:default-roles
};

declare function u:roles-for-username($username as xs:string) as xs:string* {
  u:users-int($username)/roles/role/xs:string(@name)
};

declare function u:roles-for-user($user as element(user)) as xs:string* {
  $user/roles/role/xs:string(@name)
};

declare function u:roles-for-right($right as xs:string?, $dynamic-roles as element(role)* := ()) as xs:string* {
  distinct-values((
    if ($right)
    then (u:roles()/role, $dynamic-roles)[right/@name eq $right]/xs:string(@name)
    else (u:roles()/role, $dynamic-roles)/xs:string(@name),
    
    for $role in (u:roles()/role, $dynamic-roles)
      where
      	if (exists($role/right/@matches))
        then exists($role/right[matches($right,@matches)])
        else false()
    return $role/xs:string(@name)
  ))
};

declare function u:username-for-token($token-string as xs:string) as xs:string? {
  u:get-token($token-string)?username
};

declare function u:groups(){
  distinct-values(
    u:users-int()/groups/group/xs:string(@name)
  )
};

declare function u:groups($username as xs:string?) as xs:string* {
  if ($username) then u:users-int($username)/groups/group/xs:string(@name) else ()
};

declare function u:get-new-token($username as xs:string) as (element(token)|element(error)){
  let $token := 'trui-' || random:uuid(),
      $token-map := map {'username': $username, 'token': $token, 'timestamp': current-dateTime()},
      $prev-tokens := u:get-tokens($username)[exists(.?timestamp)],
      $store := u:put-tokens($username,($prev-tokens,$token-map)),
      $log := admin:write-log('create new token for ' || $username)
  return element token {(for $key in ('username','timestamp') return attribute {$key} {$token-map?$key}),xs:string($token)}
};

(: 
 : Create a new User and add it to the Users file
 :)
declare function u:new-user($username as xs:string, $password as xs:string, $roles as xs:string* := (), $groups as xs:string* := ()) as (element(user)|element(error)) {
  if (exists(u:users-int()/user[@source eq 'file'][username/text() eq $username]))
  then element error { attribute code {'400'},'User "'|| $username ||'" exists already'}
  else
    let $new-user :=  u:create-new-user-object($username, $password, $roles, $groups),
        $users as element(users) := u:users-int(),
        $add-user := $users update {insert node $new-user into .},
        $write := u:write-users-file($add-user)
    return $new-user
};

declare %private function u:create-new-user-object($username as xs:string, $password as xs:string? := (),  $roles as xs:string* := (),  $groups as xs:string* := ()) as (element(user)|element(error)){
  let $salt := random:uuid(),
      $hashed := hash(concat($salt,($password,random:uuid())[1]),map:entry('algorithm','SHA-256')),
      $new-user :=  element user {
                      attribute source {'file'},
                      element username {$username},
                      element password {$hashed},
                      element salt {$salt},
                      element groups {
                        for $group in $groups
                        return element group {attribute name {$group}}
                      },
                      element roles {
                        for $role in $roles
                        return element role {attribute name {$role}}}
                    }
  return $new-user
};

declare function u:delete-user($username as xs:string) {
  if (file:exists($u:users-file)) then u:write-users-file(doc($u:users-file) update {delete node users/user[username eq $username]}) else ()
};

declare %private function u:write-users-file($users) {
  file:write($u:users-file,$users)
};

declare function u:validate-password($username as xs:string, $password as xs:string) as xs:boolean {
  let $user := u:users-int($username),
      $salt := $user/salt/text(),
      $hash := xs:string(hash(concat($salt,$password),map:entry('algorithm','SHA-256')))
  return xs:boolean($hash eq $user/password/text())
};

declare function u:validate-token($username as xs:string?, $token as xs:string?) as xs:boolean {
  let $prev-tokens := u:get-tokens($username),
      $matched-token := $prev-tokens[.?token eq $token],
      $is-valid := if (exists($matched-token)) then u:validate-token-bg($matched-token) else false(),
      $rest := $prev-tokens[not(.?token eq $token)],
      $updated-token := u:update-token($prev-tokens,$token, $username, $is-valid) 
  return $is-valid
};

declare function u:validate-token($token-string as xs:string?) as xs:boolean {
  if (not(exists($token-string)))
  then false()
  else
    let $token-keys := store:keys()[matches(.,'user-[^-]+-tokens')],
        $tokens :=
          for $k in $token-keys
          return store:get($k),
        $matching as map(*)* := $tokens
          [.?token eq $token-string],
        $is-valid as xs:boolean := exists($matching),
        $update :=
          for $m in $matching
          let $username := $m?username,
              $is-valid := u:validate-token-bg($m)
          return u:update-token($tokens[.?username eq $username], $token-string, $username, $is-valid)
    return $is-valid
};

declare %private function u:get-token($token-string as xs:string?) as map(*)? {
  let $token-keys := store:keys()[matches(.,'user-[^-]+-tokens')],
      $tokens :=
        for $k in $token-keys
        return store:get($k),
      $matching as map(*)* := $tokens
        [.?token eq $token-string]
  return $matching
};

declare function u:clear-tokens($username) {
  u:put-tokens($username,())
};

 (:
  : Shortcut for u:validate-token and u:can-do
  :)
declare function u:check($username as xs:string?, $token as xs:string?, $right as xs:string?, $owner as xs:string? := (), $dynamic-roles as element(role)* := ()) {
  let $is-valid := u:validate-token($username, $token),
      $is-allowed := if ($is-valid) then u:can-do(u:users-int($username), $right, $dynamic-roles, $owner) else false()
  return $is-allowed
};

declare function u:add-role($username, $rolename) {
  let $user := u:users-int($username)
  return
    if (exists($user/roles/role[@name eq $rolename]))
    then true()
    else u:write-users-file(doc($u:users-file) update {insert node element role {attribute name {$rolename}} into users/user[username eq $username]/roles})
};

declare function u:delete-role($username, $rolename) {
  let $user := u:users-int($username)
  return
    if (exists($user/roles/role[@name eq $rolename]))
    then u:write-users-file(doc($u:users-file) update {delete node users/user[username eq $username]/roles/role[@name eq $rolename]})
    else true()
};

declare function u:add-group($username, $groupname) {
  let $user := u:users-int($username)
  return
    if (exists($user/groups/group[@name eq $groupname]))
    then true()
    else u:write-users-file(u:users-int() update {insert node element group {attribute name {$groupname}} into users/user[username eq $username]/groups})
};

declare function u:delete-group($username, $groupname) {
  let $user := u:users-int($username)
  return
    if (exists($user/groups/group[@name eq $groupname]))
    then u:write-users-file(u:users-int() update {delete node users/user[username eq $username]/groups/group[@name eq $groupname]})
    else true()
};

declare function u:set-password($username, $password) {
  let $user-exists-in-file := doc($u:users-file)//user[username eq $username],
      $updated-user := u:create-new-user-object($username,$password),
      $users := if (file:exists($u:users-file)) then doc($u:users-file) else element users {},
      $add-user :=
        if ($user-exists-in-file)
        then $users update {
          replace node users/user[username eq $username]/password with $updated-user/password,
          replace node users/user[username eq $username]/salt with $updated-user/salt}
        else $users update {insert node $updated-user into .},
      $write := u:write-users-file($add-user)
  return $add-user/users/user[username eq $username]
};

declare function u:can-do($user as element(user)?, $right as xs:string, $dynamic-roles as element(role)*, $owner-name as xs:string? := ()) as xs:boolean {
  let $user-roles := $user/roles
  return
    let $matching-roles := 
      for $user-role in $user-roles/role
      where (u:roles-for-right($right, $dynamic-roles) = u:roles-for-username($user/username))
         or (if (exists($user-role/@matches)) then matches($right, $user-role/@matches) else false())
      return $user-role
    return ((count($matching-roles) gt 0) or ($owner-name eq $user/username/text()))  
};

declare %private function u:get-tokens($username) {
  store:get('user-' || $username || '-tokens')
};

declare %private function u:put-tokens($username, $tokens) {
  store:put('user-' || $username || '-tokens', $tokens)
};

declare %private function u:validate-token-bg($token as map(*)) as xs:boolean {
  ($token?timestamp => convert:dateTime-to-integer() + $u:token-max-age) gt convert:dateTime-to-integer(current-dateTime())
};

declare %private function u:update-token($tokens as map(*)*,$token-string as xs:string?, $username as xs:string?, $is-valid as xs:boolean) {
  let $token := $tokens[.?token eq $token-string],
      $rest := $tokens[not(.?token eq $token-string)],
      $updated-token := if ($is-valid) then map:put($token,'timestamp',current-dateTime()) else ()
  return u:put-tokens($username, ($rest,$updated-token))
};

declare %private function u:can-do-details($user, $right, $dynamic-roles as element(role)* := ()) as element(role)* {
let $user-roles := $user/roles
  return
    let $matching-roles := 
      for $user-role in $user-roles/role
      where (u:roles-for-right($right, $dynamic-roles) = u:roles-for-username($user/username))
         or (if (exists($user-role/@matches)) then matches($right, $user-role/@matches) else false())
      return $user-role
    return $matching-roles
};
