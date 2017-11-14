#include <iostream>
#include <stdio.h>
#include <math.h>

using namespace std;
int main()
{
  int input;
  cin>> input;
  long num=1;
  for (int i=1 ; i < input*10; i++)
  {
    for ( int j = 1; j < i ; j++)
    {
      num = num * i ;
      num = num % 57913 + j ;
      num = sqrt(num) ;
    }
  }
  cout << num << endl;
}
