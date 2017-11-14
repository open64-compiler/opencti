#include <stdio.h>
#include <malloc.h>
typedef struct
{
  int a;
  char b[150];
  int link[4];
}site ;

#define N_POINTS 3
site *lattice;
char ** gen_pt[N_POINTS];
int sites_on_node=200000;	/* number of even sites on this node */
int sum[4];


foo(int field, int j, char ** dest )
{
  int i;

  for(i=0;i<sites_on_node;i++)
  {
    sum[j] += lattice[i].link[j]/10000;
    dest[i] = (char*)(lattice+i) + field;
    lattice[i].link[j] = lattice[i].link[3-j] + 10;
  }
}

bar(int k)
{
  int j;
  int link;

  for(j = 0;  j < k; j++)
  {
    link = (char*)(&(lattice[0].link[j])) - (char*)lattice;
    foo(link, j, gen_pt[0]);
  }

}

main()
{
  int p,q,i,j,k;
  p=2;
  q=3;
  lattice = (site *)calloc(sites_on_node, sizeof(site));
  for(i=0; i < sites_on_node; i++)
  {
    for(j=0; j < 4; j++)
      lattice[i].link[j]=i*j+j;
  }
  for(i=0; i < 4; i++)
    sum[i] = 0;
  for(i=0; i < N_POINTS; i++)
    gen_pt[i] = (char **)calloc(sites_on_node, sizeof(char *));
 
  while(p>0)
  {
    p--;
    while(q>0)
    {
      q-=2;
      for(k = 1; k<=4; k++)
	bar(k);
    }
  }

  for(i=0; i < 4; i++)
  {
    printf("sum[%d]=%d\n", i, sum[i]);
  }
}
