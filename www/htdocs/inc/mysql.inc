<?
$db_hostname="moby";
$db_username="blootbot";
$db_password="IOoXuyD9";
$db_name="blootbot";

        if (! ($db_handle=@mysql_connect($db_hostname,$db_username,$db_password)) || ! @mysql_select_db($db_name)) {
        echo "<!-- MSQL ERROR! -->";
        }

?>