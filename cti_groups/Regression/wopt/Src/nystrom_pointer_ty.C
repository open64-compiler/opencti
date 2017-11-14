/*
 Nystrom alias should get TYPE of pointer, from TY on Wn node first
 instead of TY directly from ST.
 The IR for computing virtual base class's pointer is like following
       U8U8LDID 0 <2,28,this> T<77,anon_ptr.,8> {cgnode 31}
     U8U8ILOAD 0 T<74,S,8> T<77,anon_ptr.,8> <field_id:1> {cgnode 41} {alias_tag 10}
    I8I8ILOAD -24 T<5,.predef_I8,8> T<121,anon_ptr.,8> {cgnode 42} {alias_tag 9}
    U8U8LDID 0 <2,28,this> T<106,anon_ptr.,8> {cgnode 31} 
    
    <2,28,this> has differnt TYPE in two LDID, T<77,anon_ptr.,8> is TYPE of S, 
    T<106,anon_ptr.,8> is TYPE of B1.
 */
int counter = 0;

struct B1 {
	int b1m;
	B1(): b1m (0) {}
	B1& operator=(B1&) { b1m = ++counter; return *this; }
};

struct B2 {
	int b2m;
	B2(): b2m (0) {}
	B2& operator=(B2&) { b2m = ++counter; return *this; }
};

struct S : public B2, virtual public B1 {
};

int main()
{
    S s1;
	S s2;

	s2 = s1;
    // s2.b2m = 1, s2.b1m = 2
	if ( s2.b2m >= s2.b1m ) {
      return 1;
    }    
    return 0;
}

