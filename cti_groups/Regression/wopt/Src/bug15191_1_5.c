

typedef unsigned char uchar;
typedef unsigned int uint;

uchar *const_fold_test(uchar *buff, uint nod_flag, uint left_length, uint k_length )
{
   uint new_left_length, length;
   uchar *pos;
   
   new_left_length = 2 + nod_flag;
   length = new_left_length - left_length - k_length;
   // When copy propagating the value for length, the compiler should *not*
   // constant fold the '2' across the conversion, i.e.
   // buff + 2 + cvt(length) != buff + 4 + cvt(nod_flag - left_length - k_length)
   pos = buff + 2 + length;

   return pos;
}

int main()
{
   uchar buff[1024];
   uchar *ret_ptr;
   
   ret_ptr = const_fold_test(buff,1022,1010,14);
   if ( ret_ptr != &buff[2] )
      return(1);
   return(0);
}

