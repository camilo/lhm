set -e
mkdir -p ./dbdeployer/sandboxes
mkdir -p ./dbdeployer/binaries

if [ -z "$(uname | grep Darwin)" ]; then
  OS=linux
  set -x
else
  OS=osx
fi

echo "Checking if dbdeployer is installed"
if ! [ -x "$(command -v ./bin/dbdeployer)" ]; then
  echo "Not installed...starting install"
  VERSION=1.8.0
  origin=https://github.com/datacharmer/dbdeployer/releases/download/$VERSION
  filename=dbdeployer-$VERSION.$OS
  wget -q $origin/$filename.tar.gz
  tar -xzf $filename.tar.gz
  chmod +x $filename
  sudo mv $filename ./bin/dbdeployer
  rm $filename.tar.gz
else
  echo "Installation found!"
fi


echo "Checking if mysql 5.7.22 is available for dbdeployer"
if [ -z "$(./bin/dbdeployer --config ./dbdeployer/config.json --sandbox-binary "./dbdeployer/binaries" available | grep 5.7.22)" ]; then
  echo "Not found..."

  if [ "$OS" = "linux" ]; then
    MYSQL_FILE=mysql-5.7.22-linux-glibc2.12-x86_64.tar.gz
  else
    MYSQL_FILE=mysql-5.7.22-macos10.13-x86_64.tar.gz
  fi

  if [ ! -f $MYSQL_FILE ]; then
    echo "Downloading $MYSQL_FILE...(this may take a while)"
    wget -q "https://dev.mysql.com/get/Downloads/MySQL-5.7/$MYSQL_FILE"
  fi

  echo "Setting up..."
  ./bin/dbdeployer unpack $MYSQL_FILE --verbosity 0 --config ./dbdeployer/config.json --sandbox-binary "./dbdeployer/binaries"
  rm $MYSQL_FILE
else
  echo "mysql 5.7.22 found!"
fi

echo "Forcing new replication setup..."
./bin/dbdeployer deploy replication 5.7.22 --nodes 2 --force --config ./dbdeployer/config.json --sandbox-binary "./dbdeployer/binaries" --sandbox-home "./dbdeployer/sandboxes"
./bin/dbdeployer global status --config ./dbdeployer/config.json --sandbox-binary "./dbdeployer/binaries" --sandbox-home "./dbdeployer/sandboxes"

echo "Setting up database.yml"
DATABASE_YML=spec/integration/database.yml
echo "master:" > $DATABASE_YML
cat ./dbdeployer/sandboxes/rsandbox_5_7_22/master/my.sandbox.cnf | grep -A 4 client | tail -n 4 | sed -e 's/  * = /: /' -e 's/^/  /' >> $DATABASE_YML

echo "slave:" >> $DATABASE_YML
cat ./dbdeployer/sandboxes/rsandbox_5_7_22/node1/my.sandbox.cnf | grep -A 4 client | tail -n 4 | sed -e 's/  * = /: /' -e 's/^/  /' >> $DATABASE_YML

cat $DATABASE_YML

echo "You are ready to run the integration test suite..."
