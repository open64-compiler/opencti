struct X_1332Y24b
{
  int i, j;
  X_1332Y24b(int ii, int jj) : i(ii), j(jj) { }
};
X_1332Y24b x_1332Y24b(132, 51);

void f_1332Y24b(int i,
                 ...) { }

int main(int argc, char *argv[])
{

	f_1332Y24b(2, x_1332Y24b);

	struct X_1333Y17c
	{
		long Lnum;
		X_1333Y17c(long LL) { Lnum = LL+6688; }
		// operator int() const { return (Lnum); }
	};
	X_1333Y17c x(13);
}

