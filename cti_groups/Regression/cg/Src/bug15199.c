int type = 1;
int main()
{
  char *description;
  if (type == 0) {
    description = "type == 0";
  } else if (type == 1) {
    description = "type == 1";
  } else {
    description = "type != 0 && type != 1";
  }
  printf("%s\n", description);
  return 0;
}
