#include <stdio.h>
#include <stdlib.h>
#include <math.h>
struct node {
struct node *lchild;
struct node *rchild;
int data;
};
extern void process(struct node *);
void traverse( struct node *p ) 
{
    if (p->lchild)
    #pragma omp task // p is firstprivate by default
    traverse(p->lchild);
    if (p->rchild)
    #pragma omp task // p is firstprivate by default
        traverse(p->rchild);
    #pragma omp taskwait
    process(p);
}

void process(struct node* p)
{
        if (!p)
             return;
        printf("%d ",p->data);
 
} 

struct node* insert(struct node *p,int n)               
{
    static struct node *temp1,*temp2;
    if(p==NULL)
    {
        p = (struct node *)malloc(sizeof(struct node));
        p->data = n;
        p->lchild = p->rchild = NULL;
    }
    else
    {
        temp1=p;
        while(temp1 != NULL)
        {
            temp2 = temp1;
            if(n < temp1->data)
                temp1 = temp1->lchild;
            else
                temp1 = temp1->rchild;
        }
        if(temp2->data > n)
        {
            temp2->lchild = (struct node *)malloc(sizeof(struct node));
            temp2 = temp2->lchild;
            temp2->data = n;
            temp2->lchild = temp2->rchild=NULL;
        }
        else
        {
            temp2->rchild = (struct node *)malloc(sizeof(struct node));
            temp2 = temp2->rchild;
            temp2->data = n;
            temp2->lchild = temp2->rchild=NULL;
        }
    }
    return p;
}

void main()                                   //main function
{ 
    int x = 100,y,i;
    int num = x;                                     
    struct node *root = NULL;
    while(x > 0)
    {
        ///y = rand() % x; - since output needs to be verified
        y =  x;
        root=insert(root,y);
        x--; 
    }
     printf("The postorder traversal is being done\n");
     traverse(root);                     
     printf("\n");
}         
 
