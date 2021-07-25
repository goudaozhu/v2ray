for ((i=1; i<=100; i++))
do
wget http://120.232.214.103:9002/100.bin -O 100.bin  >> /dev/null
  echo $i
  sleep 1 
done
