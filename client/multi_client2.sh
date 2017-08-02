username="test_name1_"
password="test_pwd1_"

for k in $( seq 1 10 )
do
   # echo $username$k $password$k
   ./lua client_test.lua $username$k $password$k
done
