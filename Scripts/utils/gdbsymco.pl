#!/usr/bin/perl -w
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
print("welcome gdbsymco\n");

#
# gdbsymcomp
#    Tool to compare output of 2 "maint print symbol" outputs
#
# Symtab
# Blockvector
# block #000
#  globals
#  block #001
#   typename routine1
#   block #002
#    locals
#    typedef typename ...
#   typename routine

#
# line_table -- sorted numberic array
#
# scopes -- list of nodes (scopes[0] is the global scope)
#
# node -- hash type (key, name, content)
# 
# node types:
#  SCOPE
#    block, class, struct, union, routine, enum
#  OBJECT
#    variable, type,  
# All objects are simple text blocks
# A block is either a global block or routine scope or inner block


use strict;

use Switch;
use Scalar::Util;

# Node types
use constant SCOPE => 1;   # contains list of objects/scopes
use constant RECORD => 2;  # named list of objects/scopes
use constant OBJECT => 3;  # named object

# Entry comparison results
use constant UNEQUAL => 1;
use constant EQUAL => 0;
use constant SIMILAR => 2;

my $trace = 0;

my $returncode = 0;

my $buffer = "";
my $last_name;
my $end_section = 0;
# For controlling recursion
my $scope_level = 0;
# For controlling block nest level
my $block_level = 0;

# Skip record content for types we've already seen
my $ignore_content = 0;

my %ckeywords = 
(

    'and' => 1,
    'and_eq' => 1,
    'asm' => 1,
    'auto' => 1,
    'bitand' => 1,
    'bitor' => 1,
    'bool' => 1,
    'break' => 1,
    'case' => 1,
    'catch' => 1,
    'char' => 1,
    'class' => 1,
    'compl' => 1,
    'const' => 1,
    'const_cast' => 1,
    'continue' => 1,
    'default' => 1,
    'delete' => 1,
    'do' => 1,
    'double' => 1,
    'dynamic_cast' => 1,
    'else' => 1,
    'enum' => 1,
    'explicit' => 1,
    'export' => 1,
    'extern' => 1,
    'false' => 1,
    'float' => 1,
    'for' => 1,
    'friend' => 1,
    'goto' => 1,
    'if' => 1,
    'inline' => 1,
    'int' => 1,
    'long' => 1,
    'mutable' => 1,
    'namespace' => 1,
    'new' => 1,
    'not' => 1,
    'not_eq' => 1,
    'operator' => 1,
    'or' => 1,
    'or_eq' => 1,
    'private' => 1,
    'protected' => 1,
    'public' => 1,
    'register' => 1,
    'reinterpret_cast' => 1,
    'return' => 1,
    'short' => 1,
    'signed' => 1,
    'sizeof' => 1,
    'static' => 1,
    'static_cast' => 1,
    'struct' => 1,
    'switch' => 1,
    'template' => 1,
    'this' => 1,
    'throw' => 1,
    'true' => 1,
    'try' => 1,
    'typedef' => 1,
    'typeid' => 1,
    'typename' => 1,
    'union' => 1,
    'unsigned' => 1,
    'using' => 1,
    'virtual' => 1,
    'void' => 1,
    'volatile' => 1,
    'wchar_t' => 1,
    'while' => 1,
    'xor' => 1,
    'xor_eq' => 1,
);

sub is_keyword
{
    my $name = shift;
    return $ckeywords{$name};
}

sub starts_with_keyword
{
    my $name = shift;
    $name =~ s/\s*//;
    $name =~ s/(\w)/$1/;
    return $ckeywords{$name};
}

   
# Read in the two sym output files
if ($#ARGV < 2)
{
    print STDERR "Usage: gdbsymcomp name file1 file2";
    exit 1;
}

cmp_block();

my $symfile0 = read_gdbsym_file($ARGV[1]);


my $symfile1 = read_gdbsym_file($ARGV[2]);

print STDERR "===============\n" if ($trace);

# Compare all sections as appropriate
foreach my $section (keys %$symfile0)
{
    print STDERR "Comparing $section\n" if ($trace);

    if (!defined($symfile1->{$section})) 
    {
        printf STDOUT "Missing $section in file2\n";
        next;
    }

    if ($section =~ /Blockvector/) {
        visit_scopes($symfile0->{$section}, \&sort_nodes);
        visit_scopes($symfile0->{$section}, \&dump_node) if ($trace);

        visit_scopes($symfile1->{$section}, \&sort_nodes);
        visit_scopes($symfile1->{$section}, \&dump_node) if ($trace);
        
        $returncode += compare_scopes($symfile0->{$section}, $symfile1->{$section});
    }
    if ($section =~ /Line/) 
    {
        dump_lines($symfile0->{$section}) if ($trace);
        dump_lines($symfile1->{$section}) if ($trace);

        $returncode += compare_lines($symfile0->{$section}, $symfile1->{$section});
    }
}

exit $returncode;

sub dump_lines
{
    my ($lines) = @_;

    print STDOUT "Lines @$lines\n";

}

sub compare_scopes
{
    my ($scopes0, $scopes1) = @_;
    my $i0 = 0;
    my $i1 = 0;
    my $retcode = EQUAL;
    my $scope0;
    my $scope1;
    while(1)
    {
        if (!defined($scopes0->[$i0]) 
            && defined($scopes1->[$i1]) )
        {
            print STDOUT "More items in file2\n";
            $retcode = UNEQUAL;
            return $retcode;
        } elsif (!defined($scopes1->[$i1]) 
            && defined($scopes0->[$i0]) )
        {
            print STDOUT "More items in file1\n";
            $retcode = UNEQUAL;
            return $retcode;
        } elsif (!defined($scopes1->[$i1]) 
            && !defined($scopes0->[$i0]) )
        {
            return $retcode;
        }
        $scope0 = $scopes0->[$i0];
        $scope1 = $scopes1->[$i1]; 
        my $key_0 = $scope0->{key};
        my $key_1 = $scope1->{key};
        my $name_0 = $scope0->{name};
        my $name_1 = $scope1->{name};
        if (($key_0 == OBJECT && $key_1 == OBJECT) ||
            ($key_0 == RECORD && $key_1 == RECORD))
        { 
            my $text_0 = $scope0->{text};
            my $text_1 = $scope1->{text};
            if ($name_0 lt $name_1) 
            {
                print STDOUT "file1: [$name_0] not matched\n";
                $retcode = UNEQUAL;
                $i0++;
                next;
            } elsif ($name_0 gt $name_1) 
            {
                print STDOUT "file2: [$name_1] not matched\n";
                $retcode = UNEQUAL;
                $i1++;
                next;
            } elsif ($text_0 ne $text_1) 
            {
                print STDOUT "Mismatch attributes\n  file1: $name_0 ($text_0)\n  file2: $name_1 ($text_1)\n";
                $retcode = UNEQUAL;
                # return $retcode;
            }
        }             
        elsif (($key_0 == SCOPE && $key_1 != SCOPE) ||
               ($key_0 != SCOPE && $key_1 == SCOPE))
        {
                print STDOUT "Mismatch scopes file1: $name_0 vs file2: $name_1 \n";
                $retcode = UNEQUAL;
                return $retcode;
        }
        else
        {
            $retcode += compare_scopes($scope0->{content}, $scope1->{content});
        }
        $i0++;
        $i1++;
    }
    return $retcode;
}
sub compare_lines
{
    my ($lines0, $lines1) = @_;
    my $i0 = 0;
    my $i1 = 0;
    my $retcode = EQUAL;
    my $line0;
    my $line1;
    while(1)
    {
        if (!defined($lines0->[$i0]) &&
             defined($lines1->[$i1]))
        {
            print STDOUT "More lines in file2\n";
            $retcode = UNEQUAL;
            return $retcode;
        } elsif (!defined($lines1->[$i1]) &&
             defined($lines0->[$i0]))
        {
            print STDOUT "More lines in file2\n";
            $retcode = UNEQUAL;
            return $retcode;
        } elsif (!defined($lines1->[$i1]) &&
             !defined($lines0->[$i0]))
        {
            return $retcode;
        }
        $line0 = $lines0->[$i0];
        $line1 = $lines1->[$i1];
        if ($line0 < $line1)
        {
            print STDOUT "Line $line0 not found in file2\n";
            $retcode = UNEQUAL;
            $i0++;
            next;
        }
        if ($line0 > $line1)
        {
            print STDOUT "Line $line1 not found in file1\n";
            $retcode = UNEQUAL;
            $i1++;
            next;
        }
        $i0++;
        $i1++;
    }
    return $retcode;
}

#
# Routines to act on nodes
#
sub dump_node
{
    my ($scope) = @_;
    my $key = $scope->{key};
    my $name = $scope->{name};
    if ($key == SCOPE)
    { 
        print STDOUT "Scope $name\n";
    } elsif ($key == RECORD)
    { 
        my $content = $scope->{content};
        print STDOUT "Record $name\n";
        my $text = $scope->{text};
        print STDOUT "    $text\n";
    } elsif ($key == OBJECT)
    { 
        print STDOUT "Object $name\n";
        my $text = $scope->{text};
        print STDOUT "    $text\n";
    }
}
sub compare_node
{
    my $node_a = $a;
    my $node_b = $b;

    my $key_a = $node_a->{key};
    my $key_b = $node_b->{key};
    if (($key_a == OBJECT && $key_b == OBJECT) ||
        ($key_a == RECORD && $key_b == RECORD))
    { 
        my $name_a = $node_a->{name};
        my $name_b = $node_b->{name};
        print STDOUT "Comparing   $name_a $name_b\n" if ($trace);
        return $name_a cmp $name_b;
    }
    return 0;
}

#
# Sort a scope level
#
sub sort_nodes
{
    my ($scope) = @_;
    if ($scope->{key} == SCOPE || $scope->{key} == RECORD)
    {
        my $content = $scope->{content};
        my @sorted_scope = sort compare_node @$content;
        $scope->{content} = \@sorted_scope;
    }
}

#
# Node walking routines
#
sub visit_scope
{
    my ($scope, $routine) = @_;
    $routine->($scope); 
    my $content = $scope->{content};
    visit_scopes($content, $routine); 
}
sub visit_object
{
    my ($scope, $routine) = @_;
    $routine->($scope); 
}
sub visit_record
{
    my ($scope, $routine) = @_;
    $routine->($scope); 
    my $content = $scope->{content};
    visit_scopes($content, $routine); 
}
sub visit_scopes
{
    my ($scopes, $routine) = @_;
    my $scope;
    foreach $scope (@$scopes)
    {
        switch ($scope->{key})
        {
            case SCOPE { visit_scope($scope, $routine); }
            case RECORD { visit_record($scope, $routine); }
            case OBJECT { visit_object($scope, $routine); }
        }
    }
}


sub compare_comp_dirs
{
    # For now simply return true -- always will differ in testing
    # Strip off the host for gcc comparisons
    my ($val0, $val1) = @_;
    $val0 =~ s/.*://;
    $val1 =~ s/.*://;
    # return $val0 eq $val1;
    return EQUAL;
}


sub read_gdbsym_file
{
    my $file = shift;
    my $symtab_number = 0;

    $buffer = "";
    undef($last_name);
    $end_section = 0;
    $block_level = 0;
    $scope_level = 0;

    my %sections;

    # Read in the sym file
    chomp (my @input = `cat $file`);
    
    my $current_section;
    while (@input)
    {
        $_ = shift @input;
        # Sanitize the input (remove DOS characters)
        s///g;
        if (!$_)
        {
            # Ignore blank lines
            next;
        }
        $end_section = 0;
        print STDERR "See $_\n" if ($trace);

        if (/^Blockvector/)
        {
            if (defined($current_section))
            {
                print STDERR "End $current_section \n" if ($trace);
                undef $current_section;
            }
            next if (/same as previous/);
                            
            # Start of the block sections
            /(\w+)/;
            $current_section = $1 . $symtab_number;
            
            # Setup a scopes list for the new section
            my @scopes;
            $sections{$current_section} = \@scopes;
            process_scopes($sections{$current_section}, $current_section, \@input);
            next;
        }
        if (/^Symtab/)
        {
            $symtab_number++;
            if (defined($current_section))
            {
                print STDERR "End $current_section \n" if ($trace);
                undef $current_section;
            }
            # Start of the header section 
            /(\w+)/;
            $current_section = $1 . $symtab_number;
            
            # Setup a scopes list for the new section
            # my @scopes;
            # $sections{$current_section} = \@scopes;
            process_symtab($sections{$current_section}, \@input);
            next;
        }
        if (/^Line/)
        {
            if (defined($current_section))
            {
                print STDERR "End $current_section \n" if ($trace);
                undef $current_section;
            }
            # Start of the header section 
            /(\w+)/;
            $current_section = $1 . $symtab_number;
            my @line_table;
            $sections{$current_section} = \@line_table;
            process_line_table($sections{$current_section}, $current_section, \@input);
            next;
        }

    }
    
    return \%sections;
}

sub process_symtab 
{
    my ($scopes, $input) = @_;

INP2:
    while (@$input)
    {
        $_ = shift @$input;
        print STDOUT "See $_\n" if ($trace);
        if (!$_ || /^\s*$/)
        {
            last INP2;
        } else
        {
            # process up until blank line
            next;
        }
    }
}

sub find_name 
{
    my ($scopes, $name) = @_;
    my $element;
FLP:
    foreach $element (@$scopes) 
    {
        if (($element->{key} == RECORD) &&
            ($element->{name} eq $element->{name}))  
        {    
            return 1;
        }
    }
    return 0;
}

sub indent_count
{
    my $input = shift @_;
    $input =~ /^(\s*)/;
    return length($1);
}
    

#
# Recursive function to collect objects in scopes
#
sub process_scopes
{
    my ($scopes, $current_section, $input) = @_;

    my $scope_name;
    $scope_level++;

    if ($scope_level > 20)
    {
        print STDERR "Too many levels of recursion stopping at:\n";
        print STDERR "$input->[0] \n";
        exit 1;
    }

    # Process data until we hit an empty line    
    # while ($input->[0])
INP:
    while (@$input)
    {
        $_ = $input->[0];

        if (!$_)
        {
            shift @$input;
            next;
        }

        s///g;

        $_ =~ s/0x[a-f0-9]+/0x??/g;
        $buffer .= $_;

        my $indent = indent_count($_);
        if ($indent <= $block_level && $indent!=0) 
        {
            $block_level -= 2;
            return $buffer;
        }

        if (/^[A-Z]/) 
        {
            $end_section = 1;
            last INP; 
        }

        print STDERR "parsing $_\n" if ($trace);

        # Ignore blank lines
        # Anything at column 1 => next section

        # Parse the first line to determine scope/id/type
        if (/^\s*block/)
        {
            my @new_blk_scopes;
            my %new_scope_node;
            my $scope_name = process_block_name($_);
            print STDOUT "block $scope_name $scope_level\n" if ($trace);
            shift @$input;
            $block_level = indent_count($_);
            $buffer = "";
            $new_scope_node{key} = SCOPE;
            $new_scope_node{name} = $scope_name;
            process_scopes(\@new_blk_scopes, $current_section, $input); 
            $scope_level--;
            $new_scope_node{content} = \@new_blk_scopes;
            push (@$scopes, \%new_scope_node);
        } 
        if (/\}\s*;/ )
        {
            last INP;
        } 
	if (/\}\s+[\*&]*\s*(const|volatile)*\s*(\w+).*;/ )
	{
            $last_name = $2;
            last INP;
        } 
        if (/\}/) 
        {
            print STDERR "UNHANDED brace:\n $_\n";
        }
        
        if (/\{/ && !$ignore_content)
        {
            my @new_rec_scopes;
            my $record_name = process_aggr_name($_, \@$input);
            my %new_record_node;
            if (!find_name($scopes, $record_name)) 
            {
                $new_record_node{key} = RECORD;
                $new_record_node{name} = $record_name;
                $new_record_node{text} = $buffer;
            } else 
            {
                $ignore_content = 1;
            }
            shift @$input;
            process_scopes(\@new_rec_scopes, $_, $input);
            $scope_level--;
            if (!$ignore_content) 
            {
                $new_record_node{content} = \@new_rec_scopes;
                push (@$scopes, \%new_record_node);
            }
            $ignore_content = 0;

            if (defined($last_name)) {
                my %new_rec_variable_node;
                $new_rec_variable_node{key} = OBJECT;
                $new_rec_variable_node{name} = $last_name;
                $new_rec_variable_node{text} = $buffer;
                push (@$scopes, \%new_rec_variable_node);
                undef($last_name);
            }
            $buffer = "";
        } 

        if (/(\w+)\s*[\[\]\d]*\s*;/  && !$ignore_content)
        {
            my %new_variable_node;
            $new_variable_node{key} = OBJECT;
            my $name = $1;
            $new_variable_node{name} = $name;
            $new_variable_node{text} = $buffer;
            push (@$scopes, \%new_variable_node);
            $buffer = "";
        } elsif (/\(*\**(|const|volatile)*\s+([\w]+[\S]*)\)*\s*\(.*\)/ && !$ignore_content )
        {
            my %new_variable_node;
            $new_variable_node{key} = OBJECT;
            my $name = $2;
            $new_variable_node{name} = $name;
            $new_variable_node{text} = $buffer;
            push (@$scopes, \%new_variable_node);
            $buffer = "";
        } 

        last INP if ($end_section);
        shift @$input;
 
    }
    return $buffer;
}

sub process_aggr_name
{
    my ($current_line, $input) = @_;

    my $name;
    my @tokens = split (/[^{}:;\.,\w]|\s/, $current_line);

INP:
    while (@tokens)
    {
        my $tok = $tokens[0];
        if ($tok =~ /\s+/ || !$tok || starts_with_keyword($tok))
        {
            shift @tokens;
            next;
        }
        print STDERR "Aggregate $tok\n" if ($trace);
        $name = $tok;
        last INP;

    }
    if (!defined($name))
    {
        $name = "Undefined";
    }
    return $name;
}

sub process_line_table
{
    my ($line_table, $current_section, $input) = @_;
    my @lines;

    # Skip "Line table" and first (empty) line
    shift @$input;
    shift @$input;

    # Process data until we hit an empty line    
LINELP:
    while ($input->[0])
    {
        $_ = $input->[0];
        if (/\s*line\s*(\d+).*/) 
        {
            my $line = int($1);
            push(@lines, $line);
            shift @$input;
        } 
        else
        {
            last;
        }
    }
    my @sorted_lines = sort {$a <=> $b} @lines; 
    @$line_table = @sorted_lines;
    print STDOUT "@sorted_lines \n" if ($trace);
}

sub process_block_name
{
    my ($input) = @_;
    
    $input =~ /^\s*(block #\d+)/;
    my $name = $1;
    
    return $name;
}


sub scope_indent
{
    my $entry = shift;
    my $ret = "";
    for (my $i = 0; $i < $entry->{scope}; ++$i)
    {
        $ret .= "  ";
    }
    return $ret;
}


my $section;
my $subsection;
my @block_level0;
my @block_level1;
my @block_count0;
my @block_count1;
my @index0;
my @index1;
my @input0;
my @input1;
my %block0;
my %block1;
my $count_block_count0;
my $count_block_count1;
my $last_count0;
my $last_count1;
my $file;
my $testname;
my $filename;
my $cnt = 0;
my $ext;


sub cmp_block{

print("cmp_block\n\n");
chomp( @input0 = `cat $ARGV[1]` );
chomp( @input1 = `cat $ARGV[2]` );

@block_count0 = `grep -n "block #" $ARGV[1]`;
@block_count1 = `grep -n "block #" $ARGV[2]`;

$count_block_count0 = @block_count0;
$count_block_count1 = @block_count1;

array_split0(@block_count0);
array_split1(@block_count1);
array_slice0();
array_slice1();
compare_blk();
}


sub compare_blk{

print("compare_blk\n\n");
$cnt = 0;
$file = "diff";
$testname = $ARGV[0] ;
chomp($testname);
($testname,$ext) = split('\.' , $testname); 
print("testname : $testname\n");
$filename = $testname.".".$file;
print("filename : $filename\n");
open(DIFFILE,">> $filename");
foreach  (keys %block0){
print DIFFILE "\n";
print DIFFILE "\n";
print DIFFILE "\n";
if($block0{$_} ne $block1{$_}){
print DIFFILE "MASTER:";
print DIFFILE $block1{$_};
print DIFFILE "\n";
print DIFFILE "\n";
print DIFFILE "DIFF:";
print DIFFILE $block0{$_};
}
$cnt++;
}
close(DIFFILE);
}


sub array_slice0{
print("array slice0\n");
my $cnt = 0;
my $block_count0 = $count_block_count0 - 1;
my $end_cnt = 0;
my $start_cnt = 0;
my @arr;
my $arr = 0;
$last_count0 = ($index0[$block_count0] + 2);
while ($block_count0 >= 0 )
{
$start_cnt = $index0[$cnt] - 1;
$end_cnt = ($index0[$cnt + 1] - 2);
if($block_count0 != 0)
{
@arr = @input0[$start_cnt..$end_cnt];
$arr = join("\n",@arr);
$block0{$cnt} = $arr;
}
else
{
@arr = @input0[$start_cnt..($last_count0 - 2)];
$arr = join("\n",@arr);
$block0{$cnt} = $arr;
}
$cnt++;
$block_count0--;
}
}


sub array_slice1{
print("array slice1\n");
my $cnt = 0;
my $block_count1 = $count_block_count1 - 1;
my $end_cnt = 0;
my $start_cnt = 0;
my @arr;
my $arr = 0;
$last_count1 = ($index1[$block_count1] + 2);
while ($block_count1 >= 0 )
{
$start_cnt = $index1[$cnt] - 1;
$end_cnt = ($index1[$cnt + 1] - 2);
if($block_count1 != 0)
{
@arr = @input1[$start_cnt..$end_cnt];
$arr = join("\n",@arr);
$block1{$cnt} = $arr;
}
else
{
@arr = @input1[$start_cnt..($last_count0 - 2)];
$arr = join("\n",@arr);
$block1{$cnt} = $arr;
}
$cnt++;
$block_count1--;
}
}


sub array_split0{

@block_count0 = @_;
my $count = 0;

foreach (@block_count0)
{
($block_level0[$count]) = split (/,/,$_);
($index0[$count],$block_level0[$count]) = (split /:/,$block_level0[$count])[0,1];
$count++;
}
}


sub array_split1{

@block_count1 = @_;
my $count = 0;

foreach (@block_count1)
{
($block_level1[$count]) = split (/,/,$_);
($index1[$count],$block_level1[$count]) = (split /:/,$block_level1[$count])[0,1];
$count++;
}
}



