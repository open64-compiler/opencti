! This program is to test static array reduction

program array_reduction1
   implicit none
   integer, parameter :: n=10,m=10
   integer :: i
   !
   call foo1(n,m)
end program array_reduction1

subroutine foo1(n,m)
   implicit none
   integer, intent(in) :: n,m
   integer:: sumarray(10)
   integer :: omp_get_thread_num
   !
   integer :: i,j
   !
   sumarray(:)=0
!$OMP PARALLEL REDUCTION(+:sumarray), num_threads(4)
   do j=1,m
      do i=1,n
         sumarray(i)=sumarray(i)+1
      end do
   end do
!$OMP END PARALLEL
   do i=1,n
      print*,sumarray(i)
   end do

end subroutine foo1

