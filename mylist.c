#include "mylist.h"
#include <stdlib.h>
#include <stdio.h>

const List EmptyList = {NULL, NULL};

List addToListAfterData(List *list, void *newdata, void *afterdata) {
  List *headptr, *oldptr;
  headptr = list;
  if (list->data != afterdata)
    while (list->data != afterdata) {
      if (list->next == NULL)
	return *headptr;
      list = list->next;
    }
  oldptr = list->next;
  list->next = malloc(sizeof(List));
  list->next->next = oldptr;
  list->next->data = newdata;
  return *headptr;
}

List addToListAfterDataLast(List *list, void *newdata, void *afterdata) {
  List *headptr, *lastptr;
  headptr = list;
  lastptr = NULL;
  while (list != NULL) {
    if (list->data == afterdata)
      lastptr = list;
    list = list->next;
  }
  if (lastptr == NULL)
    return *headptr;
  list = lastptr;
  lastptr = list->next;
  list->next = malloc(sizeof(List));
  list->next->next = lastptr;
  list->next->data = newdata;
  return *headptr;
}

List addToListBeforeData(List *list, void *newdata, void *beforedata) {
  List *headptr, *oldptr;
  headptr=list;
  while (list != NULL) {
    if (list->data == beforedata)
      break;
    list = list->next;
  }
  if (list == NULL)
    return *headptr;
  oldptr = list->next;
  list->next = malloc(sizeof(List));
  list->next->data = beforedata;
  list->next->next = oldptr;
  list->data = newdata;
  return *headptr;
}

List addToListBeforeDataLast(List *list, void *newdata, void *beforedata) {
  List *headptr, *lastptr;
  headptr = list;
  lastptr = NULL;
  while (list != NULL) {
    if (list->data == beforedata)
      lastptr = list;
    list = list->next;
  }
  if (lastptr == NULL)
    return *headptr;
  list = lastptr;
  lastptr = list->next;
  list->next = malloc(sizeof(List));
  list->next->next = lastptr;
  list->next->data = beforedata;
  list->data = newdata;
  return *headptr;
}

List addToListAtPosition(List *list, int position, void *data) {
  List *headptr, *oldptr;
  int i;
  headptr=list;
  for(i=0;i<position;i++)
    list = list->next;
  oldptr = list->next;
  list->next = malloc(sizeof(List));
  list->next->next = oldptr;
  list->next->data = data;
  return *headptr;
}

List addToListBeginning(List *list, void *data) {
  List *headptr, *oldptr;
  headptr = list;
  oldptr = list->next;
  list->next = malloc(sizeof(List));
  list->next->next = oldptr;
  list->next->data = list->data;
  list->data = data;
  return *headptr;
}

List addToListEnd(List *list, void *data) {
  List *headptr;
  headptr = list;
  while(list->next != NULL)
    list = list->next;
  list->next = malloc(sizeof(List)+8);
  list->next->data = data;
  list->next->next = NULL;
  return *headptr;
}

List changeInListDataAtPosition(List *list, int position, void *data) {
  List *headptr;
  int i;
  headptr = list;
  for(i=0;i<position;i++)
    list = list->next;
  list->data = data;
  return *headptr;
}

List *cloneList(List *list) {
  List *clone, *headptr;
  clone = malloc(sizeof(List));
  clone->data = list->data;
  clone->next = NULL;
  headptr = clone;
  while (list->next != NULL) {
    list = list->next;
    clone->next = malloc(sizeof(List));
    clone->next->data = list->data;
    clone->next->next = NULL;
    clone = clone->next;
  }
  return headptr;
}

void *dataInListAtPosition(List *list, int position) {
  int i;
  for (i=0;i<position;i++)
    list = list->next;
  return list->data;
}

void *dataInListBeginning(List *list) {
  return list->data;
}

void *dataInListEnd(List *list) {
  while (list->next != NULL)
    list = list->next;
  return list->data;
}

List deleteFromListData(List *list, void *data) {
  List *headptr, *rmptr;
  headptr = list;
  if (list->data == data) {
    rmptr = list->next;
    list->data = list->next->data;
    list->next = list->next->next;
    free(rmptr);
    return *headptr;
  }
  while (list->next->data != data) {
    list = list->next;
    if (list->next == NULL)
      return *headptr;
  }
  rmptr = list->next;
  list->next = list->next->next;
  free(rmptr);
  return *headptr;
}

List deleteFromListEnd(List *list) {
  List *headptr, *lastptr;
  headptr = list;
  while (list->next != NULL) {
    lastptr = list;
    list = list->next;
  }
  if (list == headptr)
    return *headptr;
  else {
    free(list);
    lastptr->next = NULL;
  }
  return *headptr;
}

List *deleteFromListBeginning(List *list) {
  List *headptr;
  headptr = list->next;
  free(list);
  return headptr;
}

List deleteFromListPosition(List *list, int position) {
  List *headptr, *rmptr;
  int i;
  headptr = list;
  if (position == 0) {
    list->data = NULL;
    return *headptr;
  }
  position--;
  for(i=0;i<position;i++)
    list = list->next;
  rmptr = list->next;
  list->next = list->next->next;
  free(rmptr);
  return *headptr;
}

List deleteFromListLastData(List *list, void *data) {
  List *headptr, *lastptr;
  headptr=list;
  while (list != NULL) {
    if (list->data == data)
      lastptr = list;
    list=list->next;
  }
  list = lastptr;
  lastptr = list->next;
  if (list == headptr) {
    list->data = lastptr->data;
    if (lastptr == NULL)
      list->data = NULL;
  }
  list->next = lastptr->next;
  free(lastptr);
  return *headptr;
}

int freeList(List *list) {
  List *headptr;
  headptr = list;
  if (list->next == NULL) {
    free(list);
    return 0;
  }
  while (list->next->next != NULL)
    list = list->next;
  free(list->next);
  list->next = NULL;
  freeList(headptr);
  return 0;
}

int lastPositionInListOfData(List *list, void *data) {
  int i,j=-1;
  for(i=0;list!=NULL;list=list->next) {
    if (list->data == data)
      j=i;
    i++;
    if (list->next == NULL)
      break;
  }
  return j;
}

int lengthOfList(List *list) {
  int i;
  if (list == NULL) return 0;
  if (list->data == NULL && list->next == NULL) return 0;
  for(i=1;list->next!=NULL;list=list->next) {
    i++;
  }
  return i;
}

List *newList() {
  List *list;
  list = malloc(sizeof(List)+8);
  *list = EmptyList;
  return list;
}

int positionInListOfData(List *list, void *data) {
  int i;
  for(i=0;list!=NULL;list=list->next) {
    if (list->data == data)
      break;
    i++;
    if (list->next == NULL)
      i = -1;
  }
  return i;
}

List sortList(List *list) {
  List *headptr, *pivotptr, *next;
  void *pivot, *tmpdata;
  headptr = list;
  pivotptr = list;
  while (1) {
    pivot = list->data;
    next = list->next;
    while (next != NULL) {
      if (*(int *)pivot > *(int *)next->data) {
	tmpdata = next->data;
	next->data = pivot;
	list->data = tmpdata;
	list = next;
	next = list->next;
      } else
	next = next->next;
    }
    if (pivot == pivotptr->data)
      pivotptr = pivotptr->next;
    if (pivotptr == NULL)
      break;
    list = pivotptr;
  }
  return *headptr;
}
