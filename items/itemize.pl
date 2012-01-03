#!/usr/bin/perl -w

=cut

=head1 itemize.pl

itemize.pl - Divide a mizar article into fragments

=head1 SYNOPSIS

itemize.pl [options] mizar-article

Options:
  -help                       Brief help message
  -man                        Full documentation
  -verbose                    Say what we're doing
  -paranoid                   Check that the article is verifiable before and after we're done minimizing
  -target-directory           Save our work in a specified directory
  -stylesheet-home            Directory in which to look for needed stylesheets

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--verbose>

Say what we're doing.

=item B<--paranoid>

After itemizing, verify all of the article's fragments.

=item B<--target-directory>

Save our work in the specified directory.  It is an error if the
specified directory already exists.

=item B<--stylesheet-home=DIR>

The directory in which we will look for any needed stylesheets.

=back

=head1 DESCRIPTION

B<itemize.pl> will divide a mizar article into fragments.  The
fragments will be stored in the directory indicated by the
--target-directory option.  If that option is not supplied, we will
attempt to create, in the working directory in which this script is
called, a directory whose name is the basename of the supplied
article.  It is an error if this directory, or the directory supplied
by the --target-directory option, already exists.

=cut

# Check first that our environment is sensible

use strict;

unless (defined $ENV{"MIZFILES"}) {
  print 'Error: the MIZFILES environment variable is not set.';
  exit 1;
}

my $mizfiles = $ENV{"MIZFILES"};

unless (-e $mizfiles) {
  print 'Error: the value of the MIZFILES environment variable, ', $mizfiles, ' is invalid because there is no file or directory there.', "\n";
  exit 1;
}

unless (-d $mizfiles) {
  print 'Error: the value of the MIZFILES environment variable, ', $mizfiles, ' is invalid because it is not a directory.', "\n";
  exit 1;
}

# Look for the required programs

my @mizar_programs = ('verifier',
		      'accom',
		      'exporter',
		      'transfer',
		      'msmprocessor',
		      'wsmparser',
		      'msplit',
		      'mglue',
		      'xsltproc');

foreach my $program (@mizar_programs) {
  my $which_status = system ("which $program > /dev/null 2>&1");
  my $which_exit_code = $which_status >> 8;
  if ($which_exit_code != 0) {
    print 'Error: the required program ', $program, ' cannot be found (or is not executable)', "\n";
    exit 1;
  }
}

use File::Basename qw(basename dirname);
use XML::LibXML;
use Getopt::Long;
use Pod::Usage;
use Cwd qw(cwd);
use File::Copy qw(copy);

my $paranoid = 0;
my $stylesheet_home = '/Users/alama/sources/mizar/xsl4mizar/items';
my $verbose = 0;
my $man = 0;
my $help = 0;
my $target_directory = undef;

GetOptions('help|?' => \$help,
           'man' => \$man,
           'verbose'  => \$verbose,
	   'paranoid' => \$paranoid,
	   'stylesheet-home=s' => \$stylesheet_home,
	   'target-directory=s' => \$target_directory)
  or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
pod2usage(1) unless (scalar @ARGV == 1);

my $article = $ARGV[0];
my $article_basename = basename ($article, '.miz');
my $article_dirname = dirname ($article);
my $article_sans_extension = "${article_dirname}/${article_basename}";
my $article_miz = "${article_dirname}/${article_basename}.miz";
my $article_err = "${article_dirname}/${article_basename}.err";
my $article_evl = "${article_dirname}/${article_basename}.evl";

unless (-e $article_miz) {
  print 'Error: there is no Mizar article at ', $article_miz, "\n";
  exit 1;
}

if (-d $article_miz) {
  print 'Error: the supplied Mizar article ', $article_miz, ' is actually a directory.', "\n";
}

unless (-r $article_miz) {
  print 'Error: the Mizar article at ', $article_miz, ' is unreadable.', "\n";
  exit 1;
}

unless (-e $stylesheet_home) {
  print 'Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets does not exist.', "\n";
  exit 1;
}

unless (-d $stylesheet_home) {
  print 'Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.', "\n";
  exit 1;
}

my $split_stylesheet = "${stylesheet_home}/split.xsl";
my $itemize_stylesheet = "${stylesheet_home}/itemize.xsl";
my $wsm_stylesheet = "${stylesheet_home}/wsm.xsl";
my $extend_evl_stylesheet = "${stylesheet_home}/extend-evl.xsl";

my @stylesheets = ('split', 'itemize', 'wsm', 'extend-evl');

foreach my $stylesheet (@stylesheets) {
  my $stylesheet_path = "${stylesheet_home}/${stylesheet}.xsl";
  unless (-e $stylesheet_path) {
    print 'Error: the ', $stylesheet, ' stylesheet does not exist at the expected location (', $stylesheet_path, ').', "\n";
    exit 1;
  }
  unless (-r $stylesheet_path) {
    print 'Error: the ', $stylesheet, ' stylesheet at ', $stylesheet_path, ' is unreadable.', "\n";
    exit 1;
  }
}

if (defined $target_directory) {
  if (-e $target_directory) {
    print 'Error: the supplied target directory, ', $target_directory, ' already exists.  Please move it out of the way.', "\n";
    exit 1;
  } else {
    mkdir $target_directory
      or (print ('Error: unable to make the directory \'', $target_directory, '\'.', "\n") && exit 1);
  }
} else {
  my $cwd = cwd ();
  $target_directory = "${cwd}/${article_basename}";
  mkdir $target_directory
    or (print ('Error: unable to make the directory \'', $article_basename, '\' in the current working directory.', "\n") && exit 1);
}

# Populate the directory with what we'll eventually need

foreach my $subdir_basename ('dict', 'prel', 'text') {
  my $subdir = "${target_directory}/${subdir_basename}";
  if (-e $subdir) {
    print 'Error: there is already a \'', $subdir_basename, '\' subdirectory of the target directory ', $target_directory, '.', "\n";
    exit 1;
  }
  mkdir $subdir
    or (print ('Error: unable to make the \'', $subdir_basename, '\' subdirectory of ', $target_directory, '.', "\n") && exit 1);
}

my $target_dict_subdir = "${target_directory}/dict";
my $target_text_subdir = "${target_directory}/text";
my $target_prel_subdir = "${target_directory}/prel";

# Copy the article miz to the new subdirectory

my $article_miz_in_target_dir = "${target_directory}/${article_basename}.miz";
my $article_err_in_target_dir = "${target_directory}/${article_basename}.err";

copy ($article_miz, $article_miz_in_target_dir)
  or (print ('Error: unable to copy the article at ', $article_miz, ' to ', $article_miz_in_target_dir, '.', "\n") && exit 1);

# Transform the new miz

sub run_mizar_tool {
  my $tool = shift;
  my $article = shift;
  print $tool, '...' if $verbose;
  my $tool_status = system ("$tool -l -q $article > /dev/null 2>&1");
  print 'done.', "\n" if $verbose;
  my $tool_exit_code = $tool_status >> 8;
  unless ($tool_exit_code == 0 && -z $article_err_in_target_dir) {
    print 'Error: the ', $tool, ' Mizar tool did not exit cleanly when applied to ', $article, ' (or the .err file is non-empty).', "\n";
    exit 1;
  }
  return 1;
}

my $article_msm_in_target_dir = "${target_directory}/${article_basename}.msm";
my $article_tpr_in_target_dir = "${target_directory}/${article_basename}.tpr";

run_mizar_tool ('accom', $article_miz_in_target_dir);
run_mizar_tool ('wsmparser', $article_miz_in_target_dir);
run_mizar_tool ('msmprocessor', $article_miz_in_target_dir);
run_mizar_tool ('msplit', $article_miz_in_target_dir);

print 'Rewrite text proper...' if $verbose;
copy ($article_msm_in_target_dir, $article_tpr_in_target_dir)
  or (print ('Error: we are unable to copy ', $article_msm_in_target_dir, ' to ', $article_tpr_in_target_dir, '.', "\n") && exit 1);
print 'done.', "\n" if $verbose;

run_mizar_tool ('mglue', $article_miz_in_target_dir);
run_mizar_tool ('wsmparser', $article_miz_in_target_dir);

my $article_wsx_in_target_dir = "${target_directory}/${article_basename}.wsx";
my $article_split_wsx_in_target_dir = "${article_wsx_in_target_dir}.split";
my $article_itemized_wsx_in_target_dir = "${article_split_wsx_in_target_dir}.itemized";

unless (-e $article_wsx_in_target_dir) {
  print 'Error: the .wsx file for ', $article_basename, ' in ', $target_directory, ' does not exist.', "\n";
  exit 1;
}

print 'Split...' if $verbose;
my $xsltproc_split_status = system ("xsltproc --output $article_split_wsx_in_target_dir $split_stylesheet $article_wsx_in_target_dir 2>/dev/null");
print 'done.', "\n" if $verbose;

my $xsltproc_split_exit_code = $xsltproc_split_status >> 8;

if ($xsltproc_split_exit_code != 0) {
  print 'Error: xsltproc did not exit cleanly when applying the split stylesheet at ', $split_stylesheet, ' to ', $article_wsx_in_target_dir, '.', "\n";
  exit 1;
}

# sanity check

unless (-e $article_split_wsx_in_target_dir) {
  print 'Error: the split form of the .wsx file for ', $article_basename, ' in ', $target_directory, ' does not exist at the expected location (', $article_split_wsx_in_target_dir, ').', "\n";
  exit 1;
}

unless (-r $article_split_wsx_in_target_dir) {
  print 'Error: the split form of the .wsx file for ', $article_basename, ' in ', $target_directory, ' at ', $article_split_wsx_in_target_dir, ' is unreadable.', "\n";
  exit 1;
}

print 'Itemize...' if $verbose;
my $xsltproc_itemize_status = system ("xsltproc --output $article_itemized_wsx_in_target_dir $itemize_stylesheet $article_split_wsx_in_target_dir 2>/dev/null");
print 'done.', "\n" if $verbose;

my $xsltproc_itemize_exit_code = $xsltproc_itemize_status >> 8;
if ($xsltproc_itemize_exit_code != 0) {
  print 'Error: xsltproc did not exit cleanly when applying the itemize stylesheet at ', $itemize_stylesheet, ' to ', $article_split_wsx_in_target_dir, '.', "\n";
  exit 1;
}
