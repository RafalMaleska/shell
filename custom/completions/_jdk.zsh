#compdef _jdk jdk
if [[ ! -x $JAVA_HOME_TOOL_PATH ]]; then
  return 0
fi
line=$( $JAVA_HOME_TOOL_PATH/java_home -V 2>&1 | tr -d "[:blank:]" | grep '^[0-9]' | sed -E 's/([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
echo $line | while read line ; do compadd $line ; done
