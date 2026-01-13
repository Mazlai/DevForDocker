<?php
// Fichier de test PHP-FPM

echo "<h1>PHP-FPM fonctionne !</h1>";
echo "<h2>Informations PHP</h2>";
echo "<p>Version PHP : " . phpversion() . "</p>";
echo "<p>SAPI : " . php_sapi_name() . "</p>";
echo "<p>Date : " . date('Y-m-d H:i:s') . "</p>";

echo "<h2>Extensions chargées</h2>";
echo "<pre>";
print_r(get_loaded_extensions());
echo "</pre>";

// Pour afficher phpinfo() complet, décommenter la ligne suivante :
// phpinfo();
