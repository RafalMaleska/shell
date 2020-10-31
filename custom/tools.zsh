# kafka cli support for remote
# uses kafka-client docker image to connect to ripl kafka brokers
kafka-exec() {
	curl -s --unix-socket /var/run/docker.sock http:/_/_ping &> /dev/null
	if [[ $? -ne 0 ]] then
		echo "Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?"
		return
	fi

	cluster=$(kubectl config view --minify --output 'jsonpath={..context.cluster}')
	namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}')
	if [[ ! "$cluster" =~ ^riplf-(dev|test)-.* ]] then
		echo "Cluster '$cluster' is not supported. Check k8s context!"
		return
	fi
	stage=$(echo $cluster | cut -d'-' -f 2)
	bootstrap_server="kafka.$namespace.rikern-ingress-k8s03-$stage-riplattform.reisendeninfo.aws.db.de:9092"
	
	if [[ $1 == *"-avro-"* ]]; then
		schema_registry="--property schema.registry.url=\"https://schemaregistry.$namespace.rikern-ingress-k8s03-$stage-riplattform.reisendeninfo.aws.db.de:8081\""
		image="registry.hub.docker.com/confluentinc/confluentinc/cp-schema-registry:5.3.3"
	else
		schema_registry=""
		docker pull confluentinc/cp-kafka
		image="registry.hub.docker.com/confluentinc/cp-kafka:5.3.3"
	fi
	
	eval "docker run -it --rm --net host $image $1 --bootstrap-server $bootstrap_server $schema_registry ${@:2}"
}

kafka-avro-console-consumer() {
	kafka-exec kafka-avro-console-consumer --consumer.config /config.properties $@
}
kafka-avro-console-producer() {
	kafka-exec kafka-avro-console-producer --producer.config /config.properties $@
}
kafka-broker-api-versions() {
	kafka-exec kafka-broker-api-versions --command-config /config.properties $@
}
kafka-configs() {
	kafka-exec kafka-configs --command-config /config.properties $@
}
kafka-console-consumer() {
	kafka-exec kafka-console-consumer --consumer.config /config.properties $@
}
kafka-console-producer() {
	kafka-exec kafka-console-producer --producer.config /config.properties $@
}
kafka-consumer-groups() {
	kafka-exec kafka-consumer-groups --command-config /config.properties $@
}
kafka-delete-records() {
	kafka-exec kafka-delete-records --command-config /config.properties $@
}
kafka-consumer-perf-test() {
	kafka-exec kafka-consumer-perf-test --consumer.config /config.properties $@
}
kafka-mirror-maker() {
	kafka-exec kafka-mirror-maker --consumer.config /config.properties --producer.config /config.properties $@
}
kafka-topics() {
	kafka-exec kafka-topics --command-config /config.properties $@
}
