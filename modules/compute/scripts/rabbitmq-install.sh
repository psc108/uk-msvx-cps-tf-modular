set -euo pipefail
%{ if debug }set -x%{ endif }
if [ -f /opt/scripts/.setup-done ]; then
  cd /opt/scripts/ssl/rabbitmq0${count_index + 1}
  cp server.key server.crt ../ca/ca.crt /etc/rabbitmq
  chown rabbitmq:rabbitmq /etc/rabbitmq/server.key /etc/rabbitmq/server.crt /etc/rabbitmq/ca.crt
  systemctl enable --now rabbitmq-server
  rabbitmq-plugins enable rabbitmq_management
  if [ ${count_index} -eq 0 ]; then
    rabbitmqctl add_user admin ${rabbitmq_password}
    rabbitmqctl set_user_tags admin administrator
    cd /opt/scripts/rabbit
    ./create_users.sh ${service_password}
    ./create_vhost.sh /ssp
    cp /var/lib/rabbitmq/.erlang.cookie /opt/scripts/rabbit/rabbit01.erlang.cookie
  else
    timeout 60m sh -c 'while ! [ -f /opt/scripts/rabbit/rabbit01.erlang.cookie ] > /dev/null 2>&1; do echo Waiting for node 1...; sleep 10; done'
    cp /opt/scripts/rabbit/rabbit01.erlang.cookie /var/lib/rabbitmq/.erlang.cookie
    chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
    systemctl restart rabbitmq-server
    rabbitmqctl stop_app
    rabbitmqctl reset
    rabbitmqctl join_cluster rabbit@rabbitmq01.${private_zone_name}
    rabbitmqctl start_app
  fi
fi