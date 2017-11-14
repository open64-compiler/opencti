#!/bin/bash
# ====================================================================
#
# Copyright (C) 2011, Hewlett-Packard Development Company, L.P.
# All Rights Reserved.
#
# Open64 is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# Open64 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.
#
# ====================================================================

# iter=$1
# test_unit=$2
# test_case=$3
# fail_tag=$4

test_case=$1
output_file=$2
master_output_file=$3

test=${test_case%.*}
dump=$test.dump



##########
# OUTPUT #
##########
# Print result about IR2C dump. In case of failure, try to find if
# cause is a known issue or not.
output()
{
    location=$1
    result=$2
    diagnosis=""
    isKnown="false"

    if (test $result != "Passed") then
        isValist=`grep -c -E "\.\.\.|va_list" $test.c`
        isPragma=`grep -c "#pragma" $test.c`
        isIntrinsic=`grep -c "_Asm" $dump.err`
        isPreg=`grep -c "/* preg: " $dump.c`
        isBuffer=`grep -c "/* pointer to caller-allocated buffer" $dump.c`

        if (test $isIntrinsic != 0) then 
            diagnosis="$diagnosis intrinsic"
            isKnown="true"
        fi
        if (test $isPragma != 0) then 
            diagnosis="$diagnosis pragma"
            isKnown="true"
        fi
        if (test $isValist != 0) then 
            diagnosis="$diagnosis va_list"
            isKnown="true"
        fi
        if (test $isPreg != 0) then 
            diagnosis="$diagnosis preg"
            isKnown="true"
        fi
        if (test $isBuffer != 0) then 
            diagnosis="$diagnosis buffer"
            isKnown="true"
        fi

        if (test $isKnown = "true") then
            diagnosis="   cause? $diagnosis"
        fi
    fi

    #echo "IR2C $location $result: $test_unit/$test_case $diagnosis"
    echo "DiffPgmOut"
}



#############
# TEST_IR2c #
#############
# use ir2c to dump C code at the using the compiler option passed as
# parameter atestnd tests the correctness of the dump
test_ir2c()
{
    location=$1

    ### Extract the IR2C dump from the .err file
    rm -f $test.err $dump.*
    ./$test.compile.sh $location +Uhir2c=disambiguate -w
    #./$test.link.sh
    #./$test.run.sh
    first_dump_line=`grep -n "\-Mode:" $test.err | sed -e "s/:.*$//"`
    total_err_lines=`cat $test.err | wc -l`
    total_dump_lines=$(( $total_err_lines - $first_dump_line ))
    tail -n $total_dump_lines $test.err > $test.dump.c

    ### Add math library to the linker command line
    has_libs=`grep -c "export LIBS" $test.env`
    if (test  $has_libs > 0) then
        sed -e 's/export LIBS="\(.*\)"/export LIBS="\1 -lm"/' $test.env > $dump.env
    else
        cp $test.env $dump.env
        echo "export LIBS=-lm" >> $dump.env
    fi

    ### Reuse the compilation scripts by renaming the file names
    for i in sh compile.sh link.sh run.sh compare-out.sh
    do
        if (test -e $test.$i) then # absent if RUN_TESTS=false for instance
            sed -e "s/$test/$dump/g" $test.$i > $dump.$i
            chmod +x $dump.$i
        fi
    done

    ### Test the dump file
    ./$dump.compile.sh
    RET=$?; if (test $RET != 0) then output $location CompileErr; exit 0; fi

    if (test -e $dump.link.sh) then
        ./$dump.link.sh
        RET=$?; if (test $RET != 0) then output $location LinkErr; exit 0; fi
    fi
    
    if (test -e $dump.run.sh) then
        ./$dump.run.sh
        RET=$?; if (test $RET != 0) then output $location RunErr; exit 0; fi
    fi
    
    if (test -e $test.compare-out.sh) then
        diff $test.out $dump.out > /dev/null
        RET=$?; if (test $RET != 0) then output $location DiffErr; exit 0; fi
    fi
    
    #output $location Passed
}



########
# MAIN #
########

### Ignore files other than .c files
suffix=`echo $test_case | sed -e "s/.*\(\.c\)/\1/"`
if (test $suffix != ".c") then
  exit 1;
fi

### Generate IR for debugging
./$test.compile.sh +Uhtg=da%ir% -w 
mv $test.err $test.ir

### Run the IR2C tests at different locations in the compiler
test_ir2c "+Uhtg=da%c%"
test_ir2c "+Uhldstcanonicalizer=db%c%"

exit 0;

