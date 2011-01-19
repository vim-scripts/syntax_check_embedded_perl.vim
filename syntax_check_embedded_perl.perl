#!/usr/bin/perl -w

# Try to compile any perl code we can find embedded in the .vim file given as
# the first argument.  If errors are encountered an error message is printed to
# standard error.  If a second argument is supplied, the error message includes
# the fact that a (possibly good) version of the file is available in the file
# given as the second argument.  Of course, some code somewhere else had better
# have done something to make sure this is true.  

use strict;
use warnings;

open(SCL, ">/tmp/scl") or die;

# Get the VIM code from the specified file.
@ARGV == 1 or @ARGV == 2 or die "wrong number of arguments";

my $vim_file = $ARGV[0];
# WARNING: This check is questionable, why force extensions on users?
$vim_file =~ m/\.(?:vim|vimrc)$/
    or die "file '$vim_file' doesn't end in '.vim' or '.vimrc' (heresy)";

my $backup_file = defined($ARGV[1]) ? $ARGV[1] : undef;

open(VIM_FILE, "<$vim_file") or die "couldn't open '$vim_file' for reading";
my @vim_code_lines = <VIM_FILE>;
close(VIM_FILE) or die "couldn't close '$vim_file'";

# Get the perl chunks out of the vim file.
my @perl_chunks;
my @chunk_start_lines;
my $in_perl_chunk = 0;
my $chunk_delimiter;
my $current_chunk = "";
my $current_line_number = 0;
foreach ( @vim_code_lines ) {
    $current_line_number++;
    if ( ! $in_perl_chunk ) {
        if ( m/^\s*\:?\s*perl <<\s*(\w+)\s$/ ) {
            $in_perl_chunk = 1;
            $chunk_delimiter = $1;
            push(@chunk_start_lines, $current_line_number)
        }
    }
    else {
        if ( m/^$chunk_delimiter\s*$/ ) {
            $in_perl_chunk = 0;
            push(@perl_chunks, $current_chunk);
            $current_chunk = "";
        }
        else {
            $current_chunk .= $_
        }
    }
}

# Try to compile all the perl chunks.
my $got_errors = 0;
my $ii = 0;
foreach ( @perl_chunks ) {
    # Put goop at top to turn warnings fatal so we can postprocess them, make
    # sure we don't accidently execute the eval'ed code (except for its BEGIN,
    # END, and UNITCHECK blocks, if any), and let the interpreter know the
    # correct line number and file.  Note that perl line directive comments
    # give the number of the line following the directive (hence the +1).
    my $compile_only_chunk = (
        "use warnings FATAL => 'all'; return 1;\n".
        "# line ".($chunk_start_lines[$ii] + 1)." \"$vim_file\"\n".
        $_ );
    print SCL $compile_only_chunk;
    if ( not defined(eval($compile_only_chunk)) ) {
        my $errmsg = join("\n", $@);
        print STDERR "$errmsg\n";
        $got_errors = 1;
    }
    $ii++;
}

if ( $got_errors ) {
    # FIXME: reporting errors from this script on STDERR doesn't really work:
    # they aren't red and they don't end up in vim's message history, which
    # makes the backup file functionality largely useless.  The only real
    # fix is to use the embedded perl interpreter to do this stuff
    my $emsg = "$vim_file has embedded perl compilation errors.  ";
    if ( defined($backup_file) ) {
        $emsg .= (
            "The file has been saved anyway, but a copy of the old ".
            "(pre-save) version of the file is available in $backup_file" );
    }
    $emsg .= "\n";
    print STDERR $emsg;
    exit 1;
}
else {
    print "$vim_file embedded perl syntax OK\n";
    exit 0;
}
