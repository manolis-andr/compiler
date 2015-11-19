#ifndef __DATASTRUCTS_H__
#define __DATASTRUCTS_H__

#include <stdlib.h>
#include <stdbool.h>

/* Generic Stack and Queue datatypes		*/
/* ---------------------------------------- */

/* generic node used in Stack and Queue*/
typedef struct genNode_tag {
	void *					data;
	struct genNode_tag *	next;
} genNode;

struct Stack_tag {
	genNode *	top;
	size_t		elementSize;
};

typedef struct Stack_tag * Stack;

struct Queue_tag{
	genNode *	first;
	genNode *	last;
	size_t		elementSize;
}; 

typedef struct Queue_tag * Queue;

typedef genNode ** Iterator;


/* Generic Stack Functions */

Stack	newStack	(size_t elementSize);
void	push		(Stack stack);
void	pop			(Stack stack);
void *	top			(Stack stack);


/* Generic Queue Functions */

Queue	newQueue		(size_t elementSize);
void	addFirst		(Queue q);
void	addFirstData	(Queue q, void * data);
void	addLast			(Queue q);
void	addLastData		(Queue q, void * data);
void *	getFirst		(Queue q);
void *	getLast			(Queue q);
void *	removeFirst		(Queue q);
bool	isEmpty			(Queue q);

Iterator newIterator	(Queue q);
bool	iterHasNext		(Iterator i);
void *	iterNext		(Iterator i);
#endif
