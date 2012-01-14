#!/usr/bin/perl -w

use strict;
use File::Copy qw(copy);
use File::Basename qw(basename dirname);
use Getopt::Long;
use Pod::Usage;

my $help = 0;
my $man = 0;
my $db = undef;
my $verbose = 0;

GetOptions ("db=s"     => \$db,
            "verbose"  => \$verbose);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
pod2usage(1) if (! defined $db);

pod2usage(1) if (scalar @ARGV != 1);

sub strip_extension {
  my $path = shift;
  if ($path =~ /(.+)[.][^.]+$/) {
    return $1;
  } else {
    return $path;
  }
}

my $tptp_file = $ARGV[0];

if (! -e $tptp_file) {
  die 'Error: the supplied TPTP file,', "\n", "\n", '  ', $tptp_file, "\n", "\n", 'does not exist.';
}

if (! -r $tptp_file) {
  die 'Error: the supplied TPTP file,', "\n", "\n", '  ', $tptp_file, "\n", "\n", 'is not readable.';
}

my $tptp_basename = basename ($tptp_file);
my $tptp_sans_extension = strip_extension ($tptp_basename);

if (length $tptp_sans_extension == 0) {
  die 'Error: after stipping the extension of the supplied TPTP theory file, we are left with just the empty string, which is an unacceptable name for a Mizar article.';
}

my $tptp_short_name = substr $tptp_basename,0,8;

if ($verbose == 1) {
  print 'Using \'', $tptp_short_name, '\' as the name of the file.', "\n";
}

if (length $tptp_sans_extension > 8) {
  print STDERR ('Warning: the length of the basename of the supplied file, even when its extension is stripped, exceeds 8 characters.', "\n", 'Since Mizar articles are requires to have names at most 8 characters long, we have truncated the name to \'', $tptp_short_name, '\'.', "\n");
}

if ($tptp_short_name !~ /[a-zA-Z0-9_]{1,8}/) {
  die 'Error: the name that we will use for the Mizar article, \'', $tptp_short_name, '\', is unacceptabl as the name of a Mizar article.', "\n", 'Valid names for Mizar articles are alphanumeric characters and the underscore \'_\'.';
}

if (defined $db) {
  if (-e $db) {
    die 'Error: the specified directory', "\n", "\n", '  ', $db, "\n", "\n", 'in which we are to save our work already exists.', "\n", 'Please use a different name';
  } else {
    mkdir $db
      or die 'Error: unable to make a directory at ', $db;
  }
} else {
  if (-e $tptp_short_name) {
    die 'Error: we are to save our work in the directory \'', $tptp_short_name, '\' inferred from the name of the supplied TPTP theory.  But there is already a file or directory by that name in the current working directory.  Use the --db option to specify a destination, or move the current file or directory out of the way.';
  }
  mkdir $tptp_short_name
    or die 'Error: unable to make the directory \'', $tptp_short_name, '\' in the current working directory.';
  $db = $tptp_short_name;
}

my $tptp_dirname = dirname ($tptp_file);

# Check that tptp4X is available

my $which_tptp4X_status = system ("which tptp4X > /dev/null 2>&1");
my $which_tptp4X_exit_code = $which_tptp4X_status >> 8;

if ($which_tptp4X_exit_code != 0) {
  die 'Error: the tptp4X program is required, but does not appear to be available.';
}

my @subdirs = ('text', 'prel', 'dict');

my $stylesheet_home = '/Users/alama/sources/mizar/xsl4mizar/tptp2miz';
my $tptp2voc_stylesheet = "${stylesheet_home}/tptp2voc.xsl";
my $tptp2miz_stylesheet = "${stylesheet_home}/tptp2miz.xsl";
my @extensions = ('dco', 'dno', 'voc', 'miz');
my @stylesheets = ('tptp2dco.xsl', 'tptp2dno.xsl', 'tptp2voc.xsl');
foreach my $stylesheet (@stylesheets) {
  my $stylesheet_path = "${stylesheet_home}/${stylesheet}";
  if (! -e $stylesheet_path) {
    die 'Error: the required stylsheet ', $stylesheet, ' could not be found in the directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'where we expect to find it.';
  }
  if (! -r $stylesheet_path) {
    die 'Error: the required stylsheet ', $stylesheet, ' under', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'is not readable.';
  }
}

# Sanity check: the supplied TPTP file is well-formed according to tptp4X

my $tptp4X_check_status = system ("tptp4X -N -V -c -x -umachine $tptp_file > /dev/null 2>&1");
my $tptp4X_check_exit_code = $tptp4X_check_status >> 8;

if ($tptp4X_check_exit_code != 0) {
  die 'Error: the supplied TPTP file,', "\n", "\n", '  ', $tptp_file, "\n", "\n", 'is not a well-formed TPTP file.';
}

# XMLize the TPTP file and save it under a temporary file

my $tptp_xml = "${db}/${tptp_basename}.xml";
my $tptp4X_xmlize_status
  = system ("tptp4X -N -V -c -x -fxml $tptp_file > $tptp_xml 2> /dev/null");
my $tptp4X_xmlize_exit_code = $tptp4X_xmlize_status >> 8;
if ($tptp4X_xmlize_exit_code != 0) {
  die 'Error: tptp4X did not exit cleanly when XMLizing the TPTP file at', "\n", "\n", '  ', $tptp_file, "\n", "\n", 'Its exit code was ', $tptp4X_xmlize_exit_code, '.';
}

# Sanity check: tptp4X generated a readable XML file

if (! -e $tptp_xml) {
  die 'Error: tptp4X did not generate an XML version of the TPTP file at ', "\n", "\n", $tptp_file;
}

if (! -r $tptp_xml) {
  die 'Error: the XML reformatting of', "\n", "\n", $tptp_file, "\n", "\n", 'generated by tptp4X is not readable.';
}

my $xmllint_status = system ("xmllint --noout $tptp_xml > /dev/null 2>&1");
my $xmllint_exit_code = $xmllint_status >> 8;

if ($xmllint_exit_code != 0) {
  die 'Error: tptp4X failed to generate a valid XML document corresponding to the TPTP file at', "\n", "\n", '  ', $tptp_file;
}

# Make the required subdirectories

foreach my $dir (@subdirs) {
  mkdir "${db}/${dir}";
}

# Make the vocabulary
my $voc_file = "${db}/dict/${tptp_short_name}.voc";
my $tptp2voc_xsltproc_status = system ("xsltproc $tptp2voc_stylesheet $tptp_xml > $voc_file");
my $tptp2voc_xsltproc_exit_code = $tptp2voc_xsltproc_status >> 8;
if ($tptp2voc_xsltproc_exit_code != 0) {
  die 'Error: xsltproc did not exit cleanly when making the vocabulary (.voc) file for', "\n", "\n", '  ', $tptp_file;
}

# Make the environment
foreach my $extension ('dno', 'dco') {
  my $stylesheet = "${stylesheet_home}/tptp2${extension}.xsl";
  if (! -e $stylesheet) {
    die 'Error: the required stylesheet for generating the .', $extension, ' file does not exist at the expected location (', $stylesheet, ').';
  }
  my $output_file = "${db}/prel/${tptp_short_name}.${extension}";
  my $xsltproc_status = system ("xsltproc --stringparam article '$tptp_short_name' $stylesheet $tptp_xml > $output_file 2>/dev/null");
  my $xsltproc_exit_code = $xsltproc_status >> 8;
  if ($xsltproc_exit_code != 0) {
    die 'Error: xsltproc did not exit cleanly when generating the .', $extension, ' file for', "\n", "\n", '  ', $tptp_file, "\n", "\n", 'The exit code was ', $xsltproc_exit_code;
  }
}

# Make the .miz
my $miz_file = "${db}/text/${tptp_short_name}.miz";
my $xsltproc_status = system ("xsltproc --stringparam article '$tptp_short_name' $tptp2miz_stylesheet $tptp_xml > $miz_file 2>/dev/null");
my $xsltproc_exit_code = $xsltproc_status >> 8;
if ($xsltproc_exit_code != 0) {
  die 'Error: xsltproc did not exit cleanly when generating the .miz file for', "\n", "\n", '  ', $tptp_file, "\n", "\n", 'The exit code was ', $xsltproc_exit_code;
}

__END__

=pod

=head1 TPTP2MIZ

tptp2miz.pl - Transform a TPTP file into a Mizar article

=head1 SYNOPSIS

tptp2miz.pl [options] [tptp-file]

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--verbose>

Say what we're doing.

=item B<--db=DIRECTORY>

By default, results will be saved in a directory whose name is derived
from the name of the supplied Mizar article (stripping the '.miz'
extension, if present).  This option permits saving work to some other
directory.  It is an error if the supplied directory already exists.

=back

=head1 DESCRIPTION

B<tptp2miz.pl> will transform the supplied TPTP file into a
corresponding Mizar article.

=cut
