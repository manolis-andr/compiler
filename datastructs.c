/******************************************************************************
 
 *  C header file : datastructs.c
 *  Project       : Tony Compiler
 *  Version       : 1.0 alpha
 *  Written by    : Manolis Androulidakis
 *  Date          : November 1, 2015
 *  Description   : Generic Data Structures (Stack, Queue)
 *
 *  ---------
 *  Εθνικό Μετσόβιο Πολυτεχνείο.
 *  Σχολή Ηλεκτρολόγων Μηχανικών και Μηχανικών Υπολογιστών.
 *  Τομέας Τεχνολογίας Πληροφορικής και Υπολογιστών.
 *  Εργαστήριο Τεχνολογίας Λογισμικού
 */


#include "datastructs.h"
#include "general.h"
#include "error.h"

/* Generic Stack Functions */

Stack newStack(size_t elementSize) 
{	
	Stack s = new(sizeof(struct Stack_tag));
	s->top = NULL;
	s->elementSize = elementSize;
	return s;
}

void push(Stack stack)
{
	genNode * n = (genNode *) new(sizeof(genNode));
	n->data = new(stack->elementSize);
	n->next = stack->top;
	stack->top = n;
}

void pop(Stack stack)
{
	if(stack->top==NULL) internal("attempt to pop from empty stack");
	genNode * temp = stack->top;
	stack->top = stack->top->next;
	delete(temp->data);
	delete(temp);
}

void * top(Stack stack)	
{
	if(stack->top==NULL) fatal("attempt to access empty stack"); 
	return stack->top->data;
}


/* Generic Queue Functions */

Queue newQueue(size_t elementSize) 
{
	Queue q = new(sizeof(struct Queue_tag));
	q->first = q->last = NULL; 
	q->elementSize = elementSize;
	return q;
}

//allocates new data Node in start but does not insert data in the start
void addFirst(Queue queue)
{
	genNode * n = (genNode *) new(sizeof(genNode));
	n->data = new(queue->elementSize);
	if(queue->first==NULL){
		n->next = NULL;
		queue->last = n;
	}else
		n->next = queue->first;
	queue->first = n;
}

//does not allocate new data Node, but inserts data pointer in the start
void addFirstData(Queue q, void * data)
{
	genNode * n = (genNode *) new(sizeof(genNode));
	n->data = data;
	if(q->first==NULL){
		n->next = NULL;
		q->last = n;
	}else
		n->next = q->first;
	q->first = n;
}

//allocates new data Node in end but does not insert data at the end
void addLast(Queue queue)
{
	genNode * n = (genNode *) new(sizeof(genNode));
	n->data = new(queue->elementSize);
	n->next = NULL;
	if(queue->last==NULL){
		queue->first = n;
	}else
		queue->last->next = n;
	queue->last = n;
}

//does not allocate new data Node, but inserts data pointer at the end
void addLastData(Queue q,void * data)
{
	genNode * n = (genNode *) new(sizeof(genNode));
	n->data = data;
	n->next = NULL;
	if(q->last==NULL){
		q->first = n;
	}else
		q->last->next = n;
	q->last = n;
}

void * getFirst(Queue q) 
{ 
	if(q->first==NULL) fatal("attempt to access empty queue");
	return q->first->data;
}

void * getLast(Queue q) 
{ 
	if(q->last==NULL) fatal("attempt to access empty queue");
	return q->last->data;
}

void * removeFirst(Queue q)
{
	if(q->first==NULL) fatal("attempt to remove from empty queue");
	void * data = q->first->data;
	genNode * temp = q->first;
	q->first = q->first->next;
	if(q->first==NULL) q->last=NULL; //queue empty
	delete(temp);
	return data;
}

bool isEmpty(Queue q) {return (q->first==NULL); }

/* Returns a pointer to the first element of the Queue 
 * By calling functions iterNext and iterHasNext we can traverse the Queue.
 */
Iterator newIterator(Queue q)
{
	Iterator i = new(sizeof(Iterator));
	*i = q->first;
	return i;
}

bool	iterHasNext(Iterator i)	{ return (*i==NULL) ? false : true ; }
void *  iterNext(Iterator i)	{ void * data=(*i)->data; *i=(*i)->next;  return data;}
