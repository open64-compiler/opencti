//omp_get_wtime , omp_get_wtick

#include<iostream.h>
#include<stdlib.h>
#include<unistd.h>
#include<omp.h>

class omptest
{

public:

 void omp_get_wtime1()
 {
  double start;
  double end;
  double measured_time;
  double startwt;
  double endwt;
  double measured_wt_time;

  start = 0;
  end = 0;

  start = omp_get_wtime ();
  for (int i=0 ; i < 100; i++)
       {
         sleep(1);
       } 
  end = omp_get_wtime ();
  //cout << "omp_get_wtime :Work took sec. time. = "<< measured_wt_time<<endl;
  startwt = omp_get_wtick();
  for (int i=0 ; i < 100; i++)
       {
         sleep(1);
       } 
  endwt = omp_get_wtick();

  measured_wt_time = endwt-startwt;
  //cout << "omp_get_wtick : Work took sec. time. = "<< measured_wt_time<<endl;
 }

};


int main()
{
 omptest ompobj;
 cout<<"TEST :omp_get_wtime , omp_get_wtick"<<endl;
 ompobj.omp_get_wtime1();
}


/*

sample ourput :


omp_get_wtime :Work took sec. time. = 2.59287e-317
omp_get_wtick : Work took sec. time. = 9.53674e-07
*/
