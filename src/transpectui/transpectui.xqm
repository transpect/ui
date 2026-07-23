module namespace ui  = 'http://le-tex.de/transpectui';
import module namespace conv = 'http://le-tex.de/converter' at 'converter.xqm';
import module namespace config = 'http://le-tex.de/config' at 'config.xqm';
import module namespace hf = 'http://le-tex.de/helper-functions' at 'helper-functions.xqm';
import module namespace ns = 'http://le-tex.de/namespaces' at 'namespaces.xqm';
import module namespace i18n = 'http://le-tex.de/i18n' at 'i18n.xqm';
import module namespace make = 'http://le-tex.de/make' at 'make.xqm';
import module namespace u = 'http://le-tex.de/user' at '/opt/basex/webapp/transpectui/user.xqm';

declare function ui:check($right as xs:string?, $lang as xs:string, $return-url as xs:string?){
  let $is-allowed := ui:check-only($right)
  return
    if ($is-allowed)
    then ()
    else web:redirect(config:url( '/' ||$lang || '/' || 'error?url=' || $lang || $return-url || '&amp;message=' || i18n:static-replacement('not-allowed-message',$lang)))
};

declare function ui:check-only($right as xs:string?){
  let $username := session:get('username'),
      $token := session:get('token'),
      $is-allowed := u:check($username, $token, $right),
      $log := hf:log($username || '+' || $right || '=' || $is-allowed,'CHECK')
  return $is-allowed
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter")
  %output:method("html")
  %output:html-version('5')
function ui:converter-list($lang as xs:string){
  let $right := 'tr:list',
      $title := 'TranspectUI',
      $header := request:header-map(),
      $converters as element(converter)* := conv:get-all(),
      $url := '/converter',
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'return-url':$url}
  return
    (
      if (count($converters) eq 1)
      then
        web:redirect(config:url('/' || $lang || '/converter/' || $converters[1]/xs:string(@id)))
      else (
        ui:check($right, $lang, $url),
        element html {
          config:get-html-head($context),
          element body {
            config:get-html-header($context),
            element div {
              attribute class {'well'},
              for $converter in $converters
              let $allowed := ui:check-only($converter/@id || ':convert')
              return
                ui:create-anchor($converter/xs:string(@name), config:url('/' || $lang || '/converter/' || $converter/xs:string(@id)), 'block', $allowed)
            }
          }
        }
      )
    )
};

declare
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}")
  %output:method("html")
  %output:html-version('5')
function ui:converter-page($converter-id as xs:string, $lang as xs:string){
  let $converter := conv:get($converter-id),
      $title := $converter/xs:string(@name),
      $parameters := $converter/inputs/*,
      $url := '/converter/' || $converter-id,
      $context := map {'title': $title, 'lang': $lang, 'return-url':'/converter/', 'url':$url},
      $right := $converter-id || ':convert'
  return
    (
      ui:check($right, $lang, $url),
      element html {
        config:get-html-head($context),
        element body {
          config:get-html-header($context),
          element div {
            attribute class {'well'},
            hf:create-anchor(config:url('/' || $lang || '/converter/' || $converter-id || '/runs'),i18n:val('prev-conversions',$lang))
          },
          element div {
            attribute class {'well'},
            element form {
              attribute action {config:url('/' || $lang || '/converter/' || $converter-id || '/convert')},
              attribute method {'POST'},
              attribute enctype {"multipart/form-data"},
              for $p in $parameters
              return hf:parameter-to-html($p, $lang),
              element form-group{
                element label {
                  i18n:val("upload",$lang)
                },
                element input {
                  attribute type {'text'},
                  attribute required {''},
                  attribute readonly {''},
                  attribute name {'file-name'},
                  attribute id {'file-name'},
                  attribute class {'form-control invalid'},
                  attribute onclick {"document.querySelector('#upload_file_uploaded_data').click();document.querySelector('#submit-to-conversion').classList.remove('disabled');"},
                  attribute placeholder {i18n:val("select-file",$lang)},
                  attribute autocomplete {'off'}
                },
                element input {
                  attribute type {'file'},
                  attribute id {'upload_file_uploaded_data'},
                  attribute name {'upload_file_uploaded_data'},
                  attribute class {'hidden'}
                },
                element button {
                  attribute id {'submit-to-conversion'},
                  attribute disabled {},
                  attribute class {'primary-btn disabled'},
                  attribute type {'submit'},
                  i18n:val("submit",$lang)
                }
              }
            }
          }
        }
      }
    )
};

declare
  %rest:POST
  %rest:path("/{$lang}/converter/{$converter-id}/convert")
  %rest:form-param('upload_file_uploaded_data', '{ $file }')
  %output:method("html")
  %output:html-version('5')
function ui:run-converter($converter-id as xs:string, $file as map(xs:string, xs:base64Binary), $lang as xs:string){
  let $params := request:parameter-map(),
      $text-params := map:remove(request:parameter-map(),'upload_file_uploaded_data'),
      $converter as element(converter) := conv:get($converter-id),
      $run as element(run) := make:start-target-run('conversion', $converter, $text-params, $file, session:get('username')) 
  return if ($run/error)
         then web:redirect(config:url('/' || $lang ||'/converter/' || $converter-id || '/error/' || $run/error)) 
         else web:redirect(config:url('/' || $lang ||'/converter/' || $converter-id || '/run/'   || $run/id || '/logs'))
};

declare 
  %rest:GET
  %rest:path("/{$lang}/converter/{$converter-id}/error/{$error-message}")
  %output:method("html")
  %output:html-version('5')
function ui:error($error-message, $converter-id, $lang) {
  let $converter := conv:get($converter-id),
      $title := $converter/xs:string(@name),
      $context := map {'title': $title, 'lang': $lang, 'url':'/converter/' || $converter-id || '/error/' || $error-message, 'return-url':'/converter/' || $converter-id}
  return
    element html {
        config:get-html-head($context),
        element body {
          config:get-html-header($context),
          element div {
            attribute class {'error well'},
            $error-message
          }
        }
      }
}; 

declare
  %rest:GET
  %rest:path("/{$lang}/login")
  %output:method("html")
  %output:html-version('5')
function ui:login-frontend($lang as xs:string){
  let $title := 'TranspectUI Login',
      $url := '/login',
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'return-url': $url}
  return
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          attribute class {'well'},
          element form {
            attribute action {'do-login'},
            attribute method {'POST'},
            hf:parameter-to-html(<input type="text" name-de="Username" name-en="Username" p-name="username" required=""/>,$lang),
            hf:parameter-to-html(<input type="password" name-de="Passwort" name-en="Password" p-name="password" required=""/>,$lang),
            element form-group{
              element label {},
              element button {
                  attribute id {'submit-login'},
                  attribute class {'primary-btn'},
                  attribute type {'submit'},
                  i18n:val("login",$lang)
              }
            }
          }
        }
      }
    }
};


declare
  %rest:GET
  %rest:path("/{$lang}/error")
  %rest:query-param("url", "{$return-url}")
  %rest:query-param("message", "{$message}")
  %output:method("html")
  %output:html-version('5')
function ui:error-frontend($lang as xs:string, $return-url as xs:string?, $message as xs:string?){
  let $title := 'TranspectUI Error',
      $url := '/error',
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'return-url': $return-url}
  return
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          attribute class {'well'},
          element div {
            attribute class {'red'},
            $message
          },
          element div {
            ui:create-anchor(i18n:static-replacement('back',$lang), config:url($return-url))
          }
        }
      }
    }
};

declare
  %rest:GET
  %rest:path("/{$lang}/management")
  %output:method("html")
  %output:html-version('5')
function ui:user-management($lang){
  let $title := 'TranspectUI User Management',
      $url := '/management',
      $right := 'u:mgmt',
      $context := map {'title': $title, 'lang': $lang, 'url':$url, 'return-url': '/converter'}
  return
    (ui:check($right, $lang, $url),
    element html {
      config:get-html-head($context),
      element body {
        config:get-html-header($context),
        element div {
          attribute class {'well'},
          element div {
            for $user in u:users()/user
            return 
              element div {
                attribute class {'d-flex row'},
                element div {
                  $user/username/text()
                },
                element div {
                  distinct-values(
                    for $role in $user/roles/role
                    return xs:string($role/@name)
                  )
                },
                element div {
                  for $role in u:roles()/roles/xs:string(@name)
                  return 
                    if ($role = $user/roles/role/xs:string(@name))
                    then hf:create-anchor($lang || '/' || $user/username || '/remove-role/' || $role, 'remove ' || $role)
                    else hf:create-anchor($lang || '/' || $user/username || '/add-role/' || $role, 'add ' || $role)
                }
              }
          }
        }
      }
    }
  )
};

declare
  %rest:GET
  %rest:path("/{$lang}/logout")
  %rest:query-param("url", "{$url}")
  %output:method("html")
  %output:html-version('5')
function ui:logout($lang, $url){
  session:close(),
  web:redirect($url)
};

declare
  %rest:GET
  %rest:path("/{$lang}/session")
  %output:method("html")
  %output:html-version('5')
function ui:session($lang){
  element div {
    attribute class {'well'},
    for $name in session:names()
    return
      element div {
        element span {$name || ':' || session:get($name)}
      }
  }
};

declare
  %rest:POST
  %rest:path("/{$lang}/do-login")
  %rest:query-param("url", "{$url}")
  %rest:form-param("username", "{$username}")
  %rest:form-param("password", "{$password}")
function ui:do-login($lang as xs:string, $url as xs:string?, $username as xs:string?, $password as xs:string?){
        let $login as (element(token)|element(error)) := u:get-token($username, $password),
      $is-error := $login/self::error
  return
    if ($is-error) 
    then web:redirect('error?url=' || 'login&amp;message=' || i18n:static-replacement('login-failed',$lang))
    else (
      session:set('token', $login/self::token/text()),
      session:set('username', $username),
      if ($url) then web:redirect($url) else web:redirect('converter')
    )
};

declare function ui:create-anchor($text as xs:string? := (), $href as xs:string? := '#', $classes as xs:string* := (), $allowed as xs:boolean := true()){
  if ($allowed)
  then hf:create-anchor(config:url($href), $text, $classes)
  else
    element span {
      attribute class {string-join(($classes,'disallowed'),' ')},
      $text
    }
};


