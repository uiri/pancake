#ifndef MYLISTSTRUCT
#define MYLISTSTRUCT

typedef struct List List;

struct List {
  List *next;
  void *data;
};

#endif

extern const List EmptyList;

List addToListAfterData(List *list, void *newdata, void *afterdata);
List addToListAfterDataLast(List *list, void *newdata, void *afterdata);
List addToListAtPosition(List *list, int position, void *data);
List addToListBeforeData(List *list, void *newdata, void *beforedata);
List addToListBeforeDataLast(List *list, void *newdata, void *beforedata);
List addToListBeginning(List *list, void *data);
List addToListEnd(List *list, void *data);
List changeInListDataAtPosition(List *list, int position, void *data);
List *cloneList(List *list);
void *dataInListAtPosition(List *list, int position);
void *dataInListBeginning(List *list);
void *dataInListEnd(List *list);
List *deleteFromListBeginning(List *list);
List deleteFromListData(List *list, void *data);
List deleteFromListEnd(List *list);
List deleteFromListPosition(List *list, int position);
List deleteFromListLastData(List *list, void *data);
int freeList(List *list);
int lastPositionInListOfData(List *list, void *data);
int lengthOfList(List *list);
List *newList();
int positionInListOfData(List *list, void *data);
List sortList(List *list);
