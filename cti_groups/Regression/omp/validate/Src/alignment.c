#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "alignment.h"
#include "param.h"
#include <omp.h>



#define MIN(a,b) ((a)<(b)?(a):(b))
#define tbgap(k) ((k) <= 0 ? 0 : tb + gh * (k))
#define tegap(k) ((k) <= 0 ? 0 : te + gh * (k))

extern char **seq_array;

extern int nseqs, max_aa, max_aln_length;
extern int gap_pos1, gap_pos2, mat_avscore;
extern int gon250mt[], def_aa_xref[], *seqlen_array;

extern double pw_go_penalty, pw_ge_penalty;

int sb1, sb2, se1, se2;
int print_ptr, last_print;

int g, gh, seq1, seq2, maxscore;
#pragma omp threadprivate(sb1,sb2,se1,se2,print_ptr,last_print,g,gh,seq1,seq2,maxscore)
int *HH, *DD, *RR, *SS, *displ, matrix[NUMRES][NUMRES];
#pragma omp threadprivate(HH,DD,RR,SS,displ)


void del(int k)
{ if (last_print<0) last_print = displ[print_ptr-1] -=  k;
  else              last_print = displ[print_ptr++]  = -k;
}


void add(int v)
{ if (last_print < 0) {
     displ[print_ptr-1] = v;
     displ[print_ptr++] = last_print;
  } else {
     last_print = displ[print_ptr++] = v;
} }


int calc_score(iat, jat, v1, v2)
  int iat, jat, v1, v2;
{ int i, j, ipos, jpos;

  ipos = v1 + iat;
  jpos = v2 + jat;
  i    = seq_array[seq1][ipos];
  j    = seq_array[seq2][jpos];

  return (matrix[i][j]);
}


int get_matrix(matptr, xref, scale)
  int *matptr, *xref;
  int   scale;
{
   int gg_score = 0;
   int gr_score = 0;
   int i, j, k, ti, tj, ix;
   int av1, av2, av3, min, max, maxres;

   for (i = 0; i <= max_aa; i++)
   for (j = 0; j <= max_aa; j++) matrix[i][j] = 0;

   ix     = 0;
   maxres = 0;

   for (i = 0; i <= max_aa; i++) {
       ti = xref[i];
   for (j = 0; j <= i; j++) {
       tj = xref[j]; 
       if ((ti != -1) && (tj != -1)) {
           k = matptr[ix];
           if (ti == tj) {
               matrix[ti][ti] = k * scale;
               maxres++;
           } else {
               matrix[ti][tj] = k * scale;
               matrix[tj][ti] = k * scale;
           }
           ix++;
   } } }

   --maxres;

   av1 = av2 = av3 = 0;

   for (i = 0; i <= max_aa; i++) {
   for (j = 0; j <= i;      j++) {
       av1 += matrix[i][j];
       if (i == j) av2 += matrix[i][j];
       else        av3 += matrix[i][j];
    } }

    av1 /= (maxres*maxres)/2;
    av2 /= maxres;
    av3 /= ((double)(maxres*maxres-maxres))/2;
    mat_avscore = -av3;

    min = max = matrix[0][0];

    for (i = 0; i <= max_aa; i++)
    for (j = 1; j <= i;      j++) {
        if (matrix[i][j] < min) min = matrix[i][j];
        if (matrix[i][j] > max) max = matrix[i][j];
    }

    for (i = 0; i < gap_pos1; i++) {
        matrix[i][gap_pos1] = gr_score;
        matrix[gap_pos1][i] = gr_score;
        matrix[i][gap_pos2] = gr_score;
        matrix[gap_pos2][i] = gr_score;
     }

     matrix[gap_pos1][gap_pos1] = gg_score;
     matrix[gap_pos2][gap_pos2] = gg_score;
     matrix[gap_pos2][gap_pos1] = gg_score;
     matrix[gap_pos1][gap_pos2] = gg_score;

     maxres += 2;

     return(maxres);
}


void forward_pass(char *ia, char *ib, int n, int m)
{ int i, j, f, p, t, hh;

  maxscore  = 0;
  se1 = se2 = 0;

  for (i = 0; i <= m; i++) {HH[i] = 0; DD[i] = -g;}

  for (i = 1; i <= n; i++) {
      hh = p = 0;
      f  = -g;

  for (j = 1; j <= m; j++) {

      f -= gh; 
      t  = hh - g - gh;

      if (f < t) f = t;

      DD[j] -= gh;
      t      = HH[j] - g - gh;

      if (DD[j] < t) DD[j] = t;

      hh = p + matrix[(int)ia[i]][(int)ib[j]];
      if (hh < f) hh = f;
      if (hh < DD[j]) hh = DD[j];
      if (hh < 0) hh = 0;

      p     = HH[j];
      HH[j] = hh;

      if (hh > maxscore) {maxscore = hh; se1 = i; se2 = j;}
} } }


void reverse_pass(char *ia, char *ib)
{ int i, j, f, p, t, hh, cost;

  cost = 0;
  sb1  = sb2 = 1;

  for (i = se2; i > 0; i--){ HH[i] = -1; DD[i] = -1;}

  for (i = se1; i > 0; i--) {

        hh = f = -1;
        if (i == se1) p = 0; else p = -1;

  for (j = se2; j > 0; j--) {

      f -= gh; 
      t  = hh - g - gh;
      if (f < t) f = t;

      DD[j] -= gh;
      t      = HH[j] - g - gh;
      if (DD[j] < t) DD[j] = t;

      hh = p + matrix[(int)ia[i]][(int)ib[j]];
      if (hh < f) hh = f;
      if (hh < DD[j]) hh = DD[j];

      p     = HH[j];
      HH[j] = hh;

      if (hh > cost) {
         cost = hh; sb1 = i; sb2 = j;
         if (cost >= maxscore) break;
   }  }

      if (cost >= maxscore) break;
}  }


double tracepath(int tsb1, int tsb2)
{ int  i, k;

  int i1    = tsb1;
  int i2    = tsb2;
  int pos   = 0;
  int count = 0;

  for (i = 1; i <= print_ptr - 1; ++i) {

      if (displ[i]==0) {
         char c1 = seq_array[seq1][i1];
         char c2 = seq_array[seq2][i2];
	    
         if ((c1!=gap_pos1) && (c1 != gap_pos2) && (c1 == c2)) count++;

         ++i1; ++i2; ++pos;

      } else if ((k = displ[i]) > 0) {
	 i2  += k;
	 pos += k;
      } else {
         i1  -= k;
         pos -= k;
  }   }

  return (100.0 * (double) count);
}


int diff(A, B, M, N, tb, te)
  int A, B, M, N, tb, te;
{ int i, j, f, e, s, t, hh;
  int midi, midj, midh, type;
  
  if (N <= 0) {if (M > 0) del(M); return( - (int) tbgap(M)); }
  
  if (M <= 1) {

     if (M <= 0) {add(N); return( - (int)tbgap(N));}
    
     midh = -(tb+gh) - tegap(N);
     hh   = -(te+gh) - tbgap(N);

     if (hh > midh) midh = hh;
     midj = 0;

     for (j = 1; j <= N; j++) {
         hh = calc_score(1,j,A,B) - tegap(N-j) - tbgap(j-1);
         if (hh > midh) {midh = hh; midj = j;}
     }
    
     if (midj == 0) {
       del(1);
       add(N);
     } else {
       if (midj > 1) add(midj-1);
       displ[print_ptr++] = last_print = 0;
       if (midj < N) add(N-midj);
     }

     return midh;
  }
  
  midi  = M / 2;
  HH[0] = 0.0;
  t     = -tb;

  for (j = 1; j <= N; j++) {
      HH[j] = t = t - gh;
      DD[j] = t - g;
  }
  
  t = -tb;

  for (i = 1; i <= midi; i++) {
      s     = HH[0];
      HH[0] = hh = t = t - gh;
      f     = t - g;
  for (j = 1; j <= N; j++) {
      if ((hh = hh - g - gh)    > (f = f - gh))    f = hh;
      if ((hh = HH[j] - g - gh) > (e = DD[j]- gh)) e = hh;
      hh = s + calc_score(i,j,A,B);
      if (f > hh) hh = f;
      if (e > hh) hh = e;
      
      s = HH[j];
      HH[j] = hh;
      DD[j] = e;
  } }
  
  DD[0] = HH[0];
  RR[N] = 0;
  t     = -te;

  for (j = N-1; j >= 0; j--) {RR[j] = t = t - gh; SS[j] = t - g;}
  
  t = -te;

  for (i = M - 1; i >= midi; i--) {
      s     = RR[N];
      RR[N] = hh = t = t-gh;
      f     = t - g;
  for (j = N - 1; j >= 0; j--) {
      if ((hh = hh - g - gh)    > (f = f - gh))     f = hh;
      if ((hh = RR[j] - g - gh) > (e = SS[j] - gh)) e = hh;
      hh = s + calc_score(i+1,j+1,A,B);
      if (f > hh) hh = f;
      if (e > hh) hh = e;
      
      s     = RR[j];
      RR[j] = hh;
      SS[j] = e;
      
  } }
  
  SS[N] = RR[N];
  
  midh = HH[0] + RR[0];
  midj = 0;
  type = 1;

  for (j = 0; j <= N; j++) {
      hh = HH[j] + RR[j];
      if (hh >= midh)
         if (hh > midh || (HH[j] != DD[j] && RR[j] == SS[j]))
	    {midh = hh; midj = j;}
  }
  
  for (j = N; j >= 0; j--) {
      hh = DD[j] + SS[j] + g;
      if (hh > midh) {midh = hh;midj = j;type = 2;}
  }
  
  
  if (type == 1) {
     diff(A, B, midi, midj, tb, g);
     diff(A+midi, B+midj, M-midi, N-midj, g, te);
  } else {
     diff(A, B, midi-1, midj, tb, 0.0);
     del(2);
     diff(A+midi+1, B+midj, M-midi-1, N-midj, 0.0, te);
  }
  
  return midh;
}


int pairalign(istart, iend, jstart, jend)
  int istart, iend, jstart, jend;
{ int i, n, m, si, sj;
  int len1, len2, maxres;

  double gg, mm_score;
  int	 *mat_xref, *matptr;


  matptr   = gon250mt;
  mat_xref = def_aa_xref;

  maxres = get_matrix(matptr, mat_xref, 10);
  if (maxres == 0) return(-1);

#pragma omp parallel
{
  HH = (int *) malloc((max_aln_length) * sizeof(int));
  DD = (int *) malloc((max_aln_length) * sizeof(int));
  RR = (int *) malloc((max_aln_length) * sizeof(int));
  SS = (int *) malloc((max_aln_length) * sizeof(int));
#pragma omp barrier

  displ = (int *) malloc((2*max_aln_length+1) * sizeof(int));
#pragma omp for schedule(dynamic) private(i,n,m,si,sj,len1,len2,gg,mm_score) 
  for (si = 0; si < nseqs; si++) {
{

      if ((n = seqlen_array[si+1]) == 0) goto _end1;

      for (i = 1, len1 = 0; i <= n; i++) {
          char c = seq_array[si+1][i];
          if ((c != gap_pos1) && (c != gap_pos2)) len1++;
      }

  for (sj = si + 1; sj < nseqs; sj++) {
#pragma omp task default(shared) private(i,m,gg,len2,mm_score) firstprivate(n,si,sj,len1) \
   shared(seq_array,gap_pos1,gap_pos2,pw_ge_penalty,pw_go_penalty,mat_avscore)
{
      if ((m = seqlen_array[sj+1]) == 0) goto _end2;

      for (i = 1, len2 = 0; i <= m; i++) {
          char c = seq_array[sj+1][i];
          if ((c != gap_pos1) && (c != gap_pos2)) len2++;
      }

      gh = 10 * pw_ge_penalty;
      gg = pw_go_penalty + log((double) MIN(n, m));
      g  = (mat_avscore <= 0) ? 20 * gg : 2 * mat_avscore * gg;

      seq1 = si + 1;
      seq2 = sj + 1;

      forward_pass(&seq_array[seq1][0], &seq_array[seq2][0], n, m);
      reverse_pass(&seq_array[seq1][0], &seq_array[seq2][0]);

      print_ptr  = 1;
      last_print = 0;

      diff(sb1-1, sb2-1, se1-sb1+1, se2-sb2+1, 0, 0);
 
      mm_score = tracepath(sb1, sb2);

      if (len1 == 0 || len2 == 0) mm_score  = 0.0;
      else                        mm_score /= (double) MIN(len1,len2);
/*
#pragma omp critical
      fprintf(stdout, "Sequences (%d:%d) Aligned. Score:  %d\n",
              si + 1, sj + 1, (int) mm_score);
*/
_end2: ;
  } 
}
_end1: ;
}
}
   free(HH); free(DD);
   free(RR); free(SS); free(displ);
}
   return 0;
}


extern int *seqlen_array;
extern int nseqs, max_names, max_aln_length, gap_pos2;

extern char seqname[];
extern char **args, **names, **seq_array, *amino_acid_codes;

size_t
strlcpy(char *dst, const char *src, size_t siz)
{
        char *d = dst;
		        const char *s = src;
				        size_t n = siz;

						        /* Copy as many bytes as will fit */
								        if (n != 0) {
										                while (--n != 0) {
														                        if ((*d++ = *s++) == '\0')
																				                                break;
																												                }
																																        }

																																		        /* Not enough room in dst, add NUL and traverse rest of src */
																																				        if (n == 0) {
																																						                if (siz != 0)
																																										                        *d = '\0';                /* NUL-terminate dst */
																																																                while (*s++)
																																																				                        ;
																																																										        }

																																																												        return(s - src - 1);        /* count does not include NUL */
																																																														}



void fill_chartab(char *chartab)
{ int i;
	
  for (i = 0; i < 128; i++) chartab[i] = 0;

  for (i = 0; i < 25; i++) {
      char c = amino_acid_codes[i];
      chartab[(int)c] = chartab[tolower(c)] = c;
} }


void encode(char *seq, char *naseq, int l) 
{ int i, j;
  char c, *t;
	
  for (i = 1; i <= l; i++)
      if (seq[i] == '-') {
         naseq[i] = gap_pos2;
      } else {
         j = 0;
         c = seq[i];
         t = amino_acid_codes;
         naseq[i] = -1;
         while (t[j]) {if (t[j] == c) {naseq[i] = j; break;} j++;}
      }

  naseq[l + 1] = -3;
}


void alloc_aln(int nseqs)
{ int i,j;

  names        = (char   **) malloc((nseqs + 1) * sizeof(char *));
  seq_array    = (char   **) malloc((nseqs + 1) * sizeof(char *));
  seqlen_array = (int     *) malloc((nseqs + 1) * sizeof(int));

  for (i = 0; i < nseqs + 1; i++) {
      names[i]     = (char *  ) malloc((MAXNAMES + 1) * sizeof(char));
      seq_array[i] = NULL;
  }
}


char *get_seq(sname, len, chartab, fin)
  int  *len;
  FILE *fin;
  char *sname, *chartab;
{ int  i, j;
  char c, *seq;
  static char line[MAXLINE+1];

  *len = 0;
  seq  = NULL;

  while (*line != '>') fgets(line, MAXLINE+1, fin);
  for (i = 1; i <= strlen(line); i++) if (line[i] != ' ') break;
  for (j = i; j <= strlen(line); j++) if (line[j] == ' ') break;

  strlcpy(sname, line + i, j - i + 1);;
  sname[j - i] = EOS;

  while (fgets(line, MAXLINE+1, fin)) {
     if (seq == NULL)
        seq = (char *) malloc((MAXLINE + 2) * sizeof(char));
     else
        seq = (char *) realloc(seq, ((*len) + MAXLINE + 2) * sizeof(char));

     for (i = 0; i <= MAXLINE; i++) {
         c = line[i];
         if (c == '\n' || c == EOS || c == '>') break;
         if (c = chartab[c]) {*len += 1; seq[*len] = c;}
     }
     if (c == '>') break;
  }

  seq[*len + 1] = EOS;
  return seq;
}


int readseqs(int first_seq)
{ int  i, l1, no_seqs;
  FILE *fin;
  char *seq1, chartab[128];
	
  if ((fin = fopen(args[0], "r")) == NULL) {
     fprintf(stdout, "Could not open sequence file (%s)\n", args[0]);
     return (-1);
  }

  fscanf(fin,"Number of sequences is %d", &no_seqs);

  fill_chartab(chartab);
  strcpy(seqname, args[0]);
  fprintf(stdout, "Sequence format is Pearson\n");

  max_aln_length = 0;
  max_names      = 0;

  /* free_aln(nseqs); */
  alloc_aln(no_seqs);

  for (i = 1; i <= no_seqs; i++) {

      seq1 = get_seq(names[i], &l1, chartab, fin);

      seqlen_array[i] = l1;
      seq_array[i]    = (char *) malloc((l1 + 2) * sizeof (char));

      encode(seq1, seq_array[i], l1);

      if (l1 > max_aln_length) max_aln_length = l1;

      free(seq1);
  }

  max_aln_length *= 2;

  for (i = 1;i <= 20; i++)
      if (seqlen_array[i] > max_aln_length) max_aln_length = seqlen_array[i];
	
  for (i = 1; i<= 20; i++)
      if (strlen(names[i]) > max_names) max_names = strlen(names[i]);

  if (max_names < 10) max_names = 10;

  fclose(fin);
			
  return no_seqs;
}

int ktup, window, signif;
int prot_ktup, prot_window, prot_signif;

int gap_pos1, gap_pos2, mat_avscore;
int nseqs, max_aa, max_aln_length, max_names;
int *seqlen_array, def_aa_xref[NUMRES+1];

double gap_open,      gap_extend;
double prot_gap_open, prot_gap_extend;
double pw_go_penalty, pw_ge_penalty;
double prot_pw_go_penalty, prot_pw_ge_penalty;

char **args, **names, **seq_array, seqname[FILENAMELEN+1];


void init_matrix(void)
{ int  i, j;
  char c1, c2;

  gap_pos1 = NUMRES - 2;
  gap_pos2 = NUMRES - 1;
  max_aa   = strlen(amino_acid_codes) - 2;

  for (i = 0; i < NUMRES; i++) def_aa_xref[i]  = -1;

  for (i = 0; (c1 = amino_acid_order[i]); i++)
  for (j = 0; (c2 = amino_acid_codes[j]); j++)
      if (c1 == c2) {def_aa_xref[i] = j; break;}
}


void align()
{ int i;

  fprintf(stdout,"Multiple Pair Alignment\n\n\n");

  nseqs = readseqs(1);

  for (i = 1; i <= nseqs; i++) 
      fprintf(stdout, "Sequence %d: %-*s   %6.d aa\n",
              i, max_names, names[i], seqlen_array[i]);

  fprintf(stdout, "Start of Pairwise alignments\n");
  fprintf(stdout, "Aligning...\n");

  ktup          =  1;
  window        =  5;
  signif        =  5;
  gap_open      = 10.0;
  gap_extend    =  0.2;
  pw_go_penalty = 10.0;
  pw_ge_penalty =  0.1;

  double start,end;
  start = omp_get_wtime();
  pairalign(0, nseqs,0, nseqs);
  end = omp_get_wtime();

  fprintf(stdout, "Pairwise alignment computation time (in seconds): %lf\n",end-start);
}


int main(int argc, char **argv)
{ int i;
	
  init_matrix();
	
  if (argc < 2) {
     fprintf(stdout, "no input file ... pairalign filename\n");
  } else if (argc > 2) {
     fprintf(stdout, "too many arguments ... pairalign filename\n");
  }

  args    = (char **) malloc(sizeof(char *));
  args[0] = (char  *) malloc((strlen(argv[1])+1) * sizeof(char));
  strcpy(args[0], argv[1]);

  align();
}
