#!/bin/bash
test "$1" == "debug" && set -x

node="192.168.2.2"
node_user="admin"
mail="pablogutierrezdelc@gmail.com"
watchdog_dir="/opt/clients_watchdog"
logs_dir="$watchdog_dir/logs"
errors_dir="$watchdog_dir/errors"

[ ! -d $logs_dir ] && mkdir $logs_dir
[ ! -d $errors_dir ] && mkdir $errors_dir

pongs=0
for client in $(cat $watchdog_dir/clients.conf); do
  [ ! -f $errors_dir/$client ] && echo 0 > $errors_dir/$client
  count=$(cat $errors_dir/$client)

  if (ping -n -c1 -W2 $client &>/dev/null); then
    if (( $count > 3 )); then
      log="$(date) Se ha restablecido la conexion con el cliente $client"
      echo $log | mail -s "Conexion restablecida con el cliente $client" $mail
      echo $log >> $logs_dir/$client.log
    fi
    echo 0 > $errors_dir/$client
    ((pongs=$pongs+1))
  else
    ((count=$count+1))
    echo $count > $errors_dir/$client

    if (( $count > 3 && $count < 5 )); then
      error="$(date) El cliente $client se ha desconectado."
      echo $error >> $logs_dir/$client.log
      echo $error | mail -s "Error con el cliente $client" $mail
    fi
  fi
done

[ ! -f $errors_dir/node ] && echo 0 > $errors_dir/node
count=$(cat $errors_dir/node)
if [ $pongs == 0 ]; then
  ((count=$count+1))
  echo $count > $errors_dir/node

  if (( $count > 3 )); then
    if (ping -n -c1 -W2 $node &>/dev/null); then
      error="$(date) Ningun cliente responde, reiniciando el nodo"
      ssh $node_user@$node reboot
      [ $? -ne 0 ] && error="$error\n$(date) Error al reiniciar el nodo"
    else
      error="$(date) El nodo no responde"
    fi
    echo -e $error | mail -s "Error en el nodo $node" $mail
    echo -e $error >> $logs_dir/node.log
  fi
else
  echo 0 > $errors_dir/node
fi
