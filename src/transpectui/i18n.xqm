module namespace i18n = 'http://le-tex.de/i18n';

declare variable $i18n:languages := 
  <languages>
    <language short='de'></language>
    <language short='en'></language>
    <language short='es'></language>
    <language short='fr'></language>
  </languages>;
declare variable $i18n:static-replacements := 
  <static-replacements>
    <static-replacement tag="upload">
      <replacement lang="de">Daten hochladen</replacement>
      <replacement lang="en">Upload Data</replacement>
      <replacement lang="es">Subir Datos</replacement>
      <replacement lang="fr">Télécharger des données</replacement>
    </static-replacement>
    <static-replacement tag="prev-conversions">
      <replacement lang="de">Vorherige Konvertierungen</replacement>
      <replacement lang="en">Previous Conversions</replacement>
    </static-replacement>
    <static-replacement tag="submit-file">
      <replacement lang="de">Hochladen</replacement>
      <replacement lang="en">Submit</replacement>
      <replacement lang="es">Entregar</replacement>
      <replacement lang="fr">Télécharger</replacement>
    </static-replacement>
    <static-replacement tag="submit">
      <replacement lang="de">Abschicken</replacement>
      <replacement lang="en">Submit</replacement>
      <replacement lang="es">Entregar</replacement>
      <replacement lang="fr">Télécharger</replacement>
    </static-replacement>
    <static-replacement tag="called">
      <replacement lang="de">abgerufen</replacement>
      <replacement lang="en">retrieved</replacement>
      <replacement lang="es">consultado</replacement>
      <replacement lang="fr">consulté</replacement>
    </static-replacement>
    <static-replacement tag="select-file">
      <replacement lang="de">Datei hier auswählen</replacement>
      <replacement lang="en">Select File</replacement>
      <replacement lang="es">Seleccionar Archivo</replacement>
      <replacement lang="fr">Sélectionnez un fichier</replacement>
    </static-replacement>
    <static-replacement tag="to-results">
      <replacement lang="de">Zu den Ergebnissen</replacement>
      <replacement lang="en">Results</replacement>
      <replacement lang="es">A Los Resultados</replacement>
      <replacement lang="fr">Aux Résultats</replacement>
    </static-replacement>
    <static-replacement tag="results">
      <replacement lang="de">Ergebnisse</replacement>
      <replacement lang="en">Results</replacement>
      <replacement lang="es">Resultados</replacement>
      <replacement lang="fr">Résultats</replacement>
    </static-replacement>
    <static-replacement tag="conversions">
      <replacement lang="de">Konvertierungen</replacement>
      <replacement lang="en">Conversions</replacement>
    </static-replacement>
    <static-replacement tag="running">
      <replacement lang="de">Läuft</replacement>
      <replacement lang="en">Running</replacement>
    </static-replacement>
    <static-replacement tag="stopped">
      <replacement lang="de">Beendet</replacement>
      <replacement lang="en">Stopped</replacement>
    </static-replacement>
    <static-replacement tag="canceled">
      <replacement lang="de">Abgebrochen</replacement>
      <replacement lang="en">Canceled</replacement>
    </static-replacement>
    <static-replacement tag="pending">
      <replacement lang="de">In der Warteschlange</replacement>
      <replacement lang="en">Pending</replacement>
    </static-replacement>
    <static-replacement tag="login">
      <replacement lang="de">Anmelden</replacement>
      <replacement lang="en">Login</replacement>
    </static-replacement>
    <static-replacement tag="not-allowed-message">
      <replacement lang="de">Sie haben keinen Zugriff auf diese Ressource. Melden Sie sich mit einem anderen Nutzer an.</replacement>
      <replacement lang="en">Access to that resource denied. Login with another User.</replacement>
    </static-replacement>
    <static-replacement tag="no-cred-message">
      <replacement lang="de">Es wurde kein Authorization-Header angegeben.</replacement>
      <replacement lang="en">No Authorization Header found.</replacement>
    </static-replacement>
    <static-replacement tag="not-logged-in-message">
      <replacement lang="de">Sie sind nicht angemeldet, bitte melden Sie sich an.</replacement>
      <replacement lang="en">You are not logged in. Log in.</replacement>
    </static-replacement>
    <static-replacement tag="login-failed">
      <replacement lang="de">Anmeldung fehlgeschlagen: Username/Passwort nicht korrekt.</replacement>
      <replacement lang="en">Login failed: Username/Password not correct.</replacement>
    </static-replacement>
    <static-replacement tag="token-invalid">
      <replacement lang="de">Das angegebene Token ist nicht gültig.</replacement>
      <replacement lang="en">The supplied token is not valid.</replacement>
    </static-replacement>
    <static-replacement tag="basic-auth-disabled">
      <replacement lang="de">Anmeldung per Username/Passwort ist nicht erlaubt.</replacement>
      <replacement lang="en">Authnetication via username/password is not allowed.</replacement>
    </static-replacement>
    <static-replacement tag="bearer-auth-disabled">
      <replacement lang="de">Anmeldung per Token ist nicht erlaubt.</replacement>
      <replacement lang="en">Authnetication via tokens is not allowed.</replacement>
    </static-replacement>
    <static-replacement tag="user-preferences">
      <replacement lang="de">Nutzer-Einstellungen</replacement>
      <replacement lang="en">User Preferences</replacement>
    </static-replacement>
    <static-replacement tag="back">
      <replacement lang="de">Zurück</replacement>
      <replacement lang="en">Back</replacement>
    </static-replacement>
    <static-replacement tag="logout">
      <replacement lang="de">Abmelden</replacement>
      <replacement lang="en">Logout</replacement>
    </static-replacement>
    <static-replacement tag="result">
      <replacement lang="de">Ergebnis</replacement>
      <replacement lang="en">Result</replacement>
    </static-replacement>
    <static-replacement tag="logs">
      <replacement lang="de">Logs</replacement>
      <replacement lang="en">Logs</replacement>
    </static-replacement>
    <static-replacement tag="cancel">
      <replacement lang="de">Abbrechen</replacement>
      <replacement lang="en">Cancel</replacement>
    </static-replacement>
    <static-replacement tag="pending-conversions">
      <replacement lang="de">Warteschlange</replacement>
      <replacement lang="en">Pending Conversions</replacement>
    </static-replacement>
    <static-replacement tag="running-conversions">
      <replacement lang="de">Laufende Konvertierungen</replacement>
      <replacement lang="en">Running Conversions</replacement>
    </static-replacement>
    <static-replacement tag="run">
      <replacement lang="de">Aufruf</replacement>
      <replacement lang="en">Run</replacement>
    </static-replacement>
    <static-replacement tag="last-online">
      <replacement lang="de">zuletzt online</replacement>
      <replacement lang="en">last online</replacement>
    </static-replacement>
    <static-replacement tag="finished-conversions">
      <replacement lang="de">Beendete Konvertierungen</replacement>
      <replacement lang="en">Finished Conversions</replacement>
    </static-replacement>
    <static-replacement tag="new-conversion">
      <replacement lang="de">Neue Konvertierung starten</replacement>
      <replacement lang="en">Start New Conversion</replacement>
    </static-replacement>
    <static-replacement tag="empty-pending">
      <replacement lang="de">Keine Konvertierungen in der Warteschlange</replacement>
      <replacement lang="en">No Pending Conversions</replacement>
    </static-replacement>
    <static-replacement tag="empty-running">
      <replacement lang="de">Keine Laufenden Konvertierungen</replacement>
      <replacement lang="en">No Running Conversions</replacement>
    </static-replacement>
    <static-replacement tag="empty-finished">
      <replacement lang="de">Keine Beendeten Konvertierungen</replacement>
      <replacement lang="en">No Finished Conversions</replacement>
    </static-replacement>
    <static-replacement tag="sessions">
      <replacement lang="de">Sitzungen</replacement>
      <replacement lang="en">Sessions</replacement>
    </static-replacement>
    <static-replacement tag="roles">
      <replacement lang="de">Rollen</replacement>
      <replacement lang="en">Roles</replacement>
    </static-replacement>
    <static-replacement tag="password">
      <replacement lang="de">Passwort</replacement>
      <replacement lang="en">Password</replacement>
    </static-replacement>
    <static-replacement tag="old-password">
      <replacement lang="de">Altes Passwort</replacement>
      <replacement lang="en">Old Password</replacement>
    </static-replacement>
    <static-replacement tag="new-password">
      <replacement lang="de">Neues Passwort</replacement>
      <replacement lang="en">New Password</replacement>
    </static-replacement>
    <static-replacement tag="username">
      <replacement lang="de">Nutzername</replacement>
      <replacement lang="en">Username</replacement>
    </static-replacement>
    <static-replacement tag="add">
      <replacement lang="de">hinzufügen</replacement>
      <replacement lang="en">add</replacement>
    </static-replacement>
    <static-replacement tag="remove">
      <replacement lang="de">entfernen</replacement>
      <replacement lang="en">remove</replacement>
    </static-replacement>
    <static-replacement tag="delete">
      <replacement lang="de">Löschen</replacement>
      <replacement lang="en">Delete</replacement>
    </static-replacement>
    <static-replacement tag="user">
      <replacement lang="de">Nutzer</replacement>
      <replacement lang="en">Users</replacement>
    </static-replacement>
    <static-replacement tag="new-user">
      <replacement lang="de">Neuen Nutzer anlegen</replacement>
      <replacement lang="en">Create New User</replacement>
    </static-replacement>
    <static-replacement tag="converters">
      <replacement lang="de">Konverter</replacement>
      <replacement lang="en">Converters</replacement>
    </static-replacement>
    <static-replacement tag="workers">
      <replacement lang="de">Worker</replacement>
      <replacement lang="en">Worker</replacement>
    </static-replacement>
    <static-replacement tag="worker">
      <replacement lang="de">Worker</replacement>
      <replacement lang="en">Worker</replacement>
    </static-replacement>
    <static-replacement tag="on-worker">
      <replacement lang="de">Auf Worker</replacement>
      <replacement lang="en">On Worker</replacement>
    </static-replacement>
    <static-replacement tag="requires-right">
      <replacement lang="de">Benötigt Recht</replacement>
      <replacement lang="en">requires right</replacement>
    </static-replacement>
    <static-replacement tag="requires-role">
      <replacement lang="de">Benötigt Rolle</replacement>
      <replacement lang="en">requires role</replacement>
    </static-replacement>
    <static-replacement tag="in-role">
      <replacement lang="de">als Rolle</replacement>
      <replacement lang="en">as role</replacement>
    </static-replacement>
    <static-replacement tag="start">
      <replacement lang="de">Startseite</replacement>
      <replacement lang="en">Landing Page</replacement>
    </static-replacement>
    <static-replacement tag="or">
      <replacement lang="de">oder</replacement>
      <replacement lang="en">or</replacement>
    </static-replacement>
    <static-replacement tag="and">
      <replacement lang="de">und</replacement>
      <replacement lang="en">and</replacement>
    </static-replacement>
    <static-replacement tag="api-tut-get-token">
      <replacement lang="de">Ein TOKEN via /api/de/token/get holen und als Authorization-Header benutzen: -H "Authorization: Bearer TOKEN"</replacement>
      <replacement lang="en">Get a TOKEN via /api/en/token/get and use it as authorization header: -H "Authorization: Bearer TOKEN"</replacement>
    </static-replacement>
    <static-replacement tag="api-tut-get-converter">
      <replacement lang="de">Information zu Konvertern: /api/de/converter oder eines bestimmten Konverters: /api/de/converter/CONVERTER-ID</replacement>
      <replacement lang="en">Get Information about converters: /api/de/converter or of a specific converter: /api/en/converter/CONVERTER-ID</replacement>
    </static-replacement>
    <static-replacement tag="dragDrop">
      <replacement lang="de">Ziehen Sie eine Datei hierher</replacement>
      <replacement lang="en">Drag and drop your file here</replacement>
    </static-replacement>
    <static-replacement tag="clickToChoose">
      <replacement lang="de">oder klicken Sie um eine Datei auszuwählen</replacement>
      <replacement lang="en">or click to choose a file</replacement>
    </static-replacement>
  </static-replacements>;

declare function i18n:val($tag, $lang) {
  i18n:static-replacement($tag, $lang)
};
declare function i18n:static-replacement($tag, $lang) {
  $i18n:static-replacements/static-replacement[@tag eq $tag]/replacement[@lang eq $lang]/text()
};

declare function i18n:name($input, $lang as xs:string := 'de') as xs:string{
  let $name := ($input/@*[local-name(.) eq 'name-' || $lang], $input/@name, $input/@name-en, $input/@name-en)[1] => xs:string(),
      $log := admin:write-log($lang || ': ' ||  $name,'i18n')
  return $name
};