#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <assert.h>
struct node {
int data;
struct node *next;
};

typedef struct node node;

void process(struct node * p);
void increment_list_items(node * head)
{
#pragma omp parallel
{
#pragma omp single
{
  node * p = head;
  while (p) {
#pragma omp task
    // p is firstprivate by default
    process(p);
    p = p->next;
  }
}
}
}

void process(struct node* p)
{
        if (!p)
             return;
        p->data++; 
 
} 
void print(struct node* p)
{
        if (!p)
             return;
        while(p)
        {
           printf("%d ",p->data);
           p = p->next;
        }  
} 

struct node* insert(struct node *p,int n)               
{
    static struct node *temp1,*temp2;
    if(p==NULL)
    {
        p = (struct node *)malloc(sizeof(struct node));
        p->data = n;
        p->next = NULL;
        return p;
    }
    else
    {
        temp1=p;
        while(temp1->next != NULL)
        {
            temp1 = temp1->next;
        }
        assert (temp1->next == NULL);
        temp1->next = (struct node *)malloc(sizeof(struct node));
        temp1->next->data = n;
        temp1->next->next = NULL;
        return p;
    }
}

int main()                                   //main function
{ 
    int x = 100,y,i;
    int num = x;                                     
    struct node *root = NULL;
    while(x > 0)
    {
        //y = rand() % x;
        y = x; 
        root=insert(root,y);
        x--; 
    }
     printf("Before\n"); 
     print(root);
     increment_list_items(root);                     
     printf("\nAfter\n"); 
     print(root);
     printf("\n");
}         
 
