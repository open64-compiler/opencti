!This program is to test dynamic array reduction

program array_reduction1
   implicit none
   integer, parameter :: n=10,m=10
   integer :: i
   integer, dimension(n) :: sumarray
   !
   call foo1(n,m,sumarray)
   do i=1,n
      print*,sumarray(i)
   end do
end program array_reduction1

subroutine foo1(n,m,sumarray)
   implicit none
   integer, intent(in) :: n,m
   integer, dimension(n), intent(out) :: sumarray
   integer :: omp_get_thread_num
   !
   integer :: i,j
   !
   sumarray(:)=0
!$OMP PARALLEL REDUCTION(+:sumarray),num_threads(4)
   do j=1,m
      do i=1,n
         sumarray(i)=sumarray(i)+1
      end do
   end do
!$OMP END PARALLEL
end subroutine foo1

