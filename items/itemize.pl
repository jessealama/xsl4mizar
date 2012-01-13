#!/usr/bin/perl -w

# Check first that our environment is sensible

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

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

# Check that xsltproc is available
my $which_xsltproc_status = system ('which xsltproc > /dev/null 2>&1');
my $which_xsltproc_exit_code = $which_xsltproc_status >> 8;
if ($which_xsltproc_exit_code != 0) {
  print 'Error: the xsltproc program is not available.', "\n";
  exit 1;
}

use File::Basename qw(basename dirname);
use XML::LibXML;
use Getopt::Long;
use Pod::Usage;
use Cwd qw(cwd);
use File::Copy qw(copy);

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
  if (-e $target_directory) {
    print 'Error: since the target-directory option was not used, we are to save our wok in \'', $article_basename, '\'; but there is already a directory by that name in the current working directory.  Please move it out of the way.', "\n";
    exit 1;
  }
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
my $article_miz_orig_in_target_dir = "${target_directory}/${article_basename}.miz.orig";
my $article_err_in_target_dir = "${target_directory}/${article_basename}.err";

copy ($article_miz, $article_miz_in_target_dir)
  or (print ('Error: unable to copy the article at ', $article_miz, ' to ', $article_miz_in_target_dir, '.', "\n") && exit 1);
copy ($article_miz, $article_miz_orig_in_target_dir)
  or (print ('Error: unable to copy the article at ', $article_miz, ' to ', $article_miz_orig_in_target_dir, '.', "\n") && exit 1);

# Transform the new miz

sub run_mizar_tool {
  my $tool = shift;
  my $article_file = shift;
  my $article_base = basename ($article_file, '.miz');
  my $article_err_file = "${article_base}.err";
  my $tool_status = system ("$tool -l -q $article_file > /dev/null 2>&1");
  my $tool_exit_code = $tool_status >> 8;
  unless ($tool_exit_code == 0 && -z $article_err_file) {
    if ($verbose) {
      print 'Error: the ', $tool, ' Mizar tool did not exit cleanly when applied to ', $article_file, ' (or the .err file is non-empty).', "\n";
    }
    return 0;
  }
  return 1;
}

my $article_evl_in_target_dir = "${target_directory}/${article_basename}.evl";
my $article_msm_in_target_dir = "${target_directory}/${article_basename}.msm";
my $article_tpr_in_target_dir = "${target_directory}/${article_basename}.tpr";

my $accom_ok = run_mizar_tool ('accom', $article_miz_in_target_dir);
if ($accom_ok == 0) {
  print 'Error: the initial article did not could not be accom\'d.';
  exit 1;
}

my $verifier_ok = run_mizar_tool ('verifier', $article_miz_in_target_dir);
if ($verifier_ok == 0) {
  print 'Error: the initial article could not be verified.';
  exit 1;
}

my $wsmparser_ok = run_mizar_tool ('wsmparser', $article_miz_in_target_dir);
if ($wsmparser_ok == 0) {
  print 'Error: wsmparser failed on the initial article.';
  exit 1;
}

my $msmprocessor_ok = run_mizar_tool ('msmprocessor', $article_miz_in_target_dir);
if ($msmprocessor_ok == 0) {
  print 'Error: msmprocessor failed on the initial article.';
  exit 1;
}

my $msplit_ok = run_mizar_tool ('msplit', $article_miz_in_target_dir);
if ($msplit_ok == 0) {
  print 'Error: msplit failed on the initial article.';
  exit 1;
}

print 'Rewrite text proper...' if $verbose;
copy ($article_msm_in_target_dir, $article_tpr_in_target_dir)
  or (print ('Error: we are unable to copy ', $article_msm_in_target_dir, ' to ', $article_tpr_in_target_dir, '.', "\n") && exit 1);
print 'done.', "\n" if $verbose;

my $mglue_ok = run_mizar_tool ('mglue', $article_miz_in_target_dir);
if ($mglue_ok == 0) {
  print 'Error: mglue failed on the initial article.';
  exit 1;
}

$wsmparser_ok = run_mizar_tool ('wsmparser', $article_miz_in_target_dir);
if ($wsmparser_ok == 0) {
  print 'Error: wsmparser failed on the WSMified article.';
  exit 1;
}

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

# Load the article's environment

unless (-e $article_evl_in_target_dir) {
  print 'Error: the .evl file for ', $article_basename, ' does not exist.', "\n";
  exit 1;
}

unless (-r $article_evl_in_target_dir) {
  print 'Error: the .evl file for ', $article_basename, ' is unreadable.', "\n";
  exit 1;
}

my $xml_parser = XML::LibXML->new (suppress_warnings => 1,
				   suppress_errors => 1);

my $article_evl_doc = undef;
eval {
  $article_evl_doc = $xml_parser->parse_file ($article_evl_in_target_dir);
};
if ($@) {
  print 'Error: ', $article_evl_in_target_dir, ' is not well-formed XML.', "\n";
  exit 1;
}

sub ident_name {
  my $ident_node = shift;
  return ($ident_node->getAttribute ('name'));
}

my @notations_nodes
  = $article_evl_doc->findnodes ('Environ/Directive[@name = "Notations"]/Ident[@name]');
my @notations = map { ident_name($_) } @notations_nodes;
my @registrations_nodes
  = $article_evl_doc->findnodes ('Environ/Directive[@name = "Registrations"]/Ident[@name]');
my @registrations = map { ident_name($_) } @registrations_nodes;
my @definitions_nodes
  = $article_evl_doc->findnodes ('Environ/Directive[@name = "Definitions"]/Ident[@name]');
my @definitions = map { ident_name($_) } @definitions_nodes;
my @theorems_nodes
  = $article_evl_doc->findnodes ('Environ/Directive[@name = "Theorems"]/Ident[@name]');
my @theorems = map { ident_name($_) } @theorems_nodes;
my @schemes_nodes
  = $article_evl_doc->findnodes ('Environ/Directive[@name = "Schemes"]/Ident[@name]');
my @schemes = map { ident_name($_) } @schemes_nodes;
my @constructors_nodes
  = $article_evl_doc->findnodes ('Environ/Directive[@name = "Constructors"]/Ident[@name]');
my @constructors = map { ident_name($_) } @constructors_nodes;

# Now print the items

my $itemized_article_doc = undef;

eval {
  $itemized_article_doc
    = $xml_parser->parse_file ($article_itemized_wsx_in_target_dir);
};

if ($@) {
  print 'Error: the XML in ', $article_itemized_wsx_in_target_dir, ' is not well-formed.', "\n";
  exit 1;
}

sub list_as_token_string {
  my @lst = @{shift ()};
  my $val = '';
  my $num_elements = scalar @lst;
  for (my $i = 0; $i < $num_elements; $i++) {
    $val .= $lst[$i];
    $val .= ',';
  }
  return $val;
}

sub fragment_number {
  my $fragment_path = shift;
  $fragment_path =~ m/^ckb([0-9]+)\./;
  my $fragment_number = $1;
  if (defined $fragment_number) {
    return $fragment_number;
  } else {
    print 'Error: we could not extract the fragment number from the path \'', $fragment_path, '\'.', "\n";
    exit 1;
  }
}

my @fragments = $itemized_article_doc->findnodes ('/Fragments/Text-Proper');

if ($verbose && scalar @fragments == 0) {
  print 'Warning: there are 0 Fragment elements in the itemized wsx file for ', $article_basename, ' at ', $article_itemized_wsx_in_target_dir, '.', "\n";
}

# Separate the XML for the fragments into separate files

foreach my $i (1 .. scalar @fragments) {
  my $fragment = $fragments[$i - 1];
  my $fragment_doc = XML::LibXML::Document->createDocument ();
  $fragment->setAttribute ('original-article', $article_basename);
  $fragment->setAttribute ('fragment-number', $i);
  $fragment_doc->setDocumentElement ($fragment);
  my $fragment_path = "${target_directory}/fragment-${i}.wsx";
  $fragment_doc->toFile ($fragment_path);
}

chdir $target_directory
  or (print ('Error: unable to change directory to ', $target_directory, '.', "\n") && exit 1);

foreach my $i (1 .. scalar @fragments) {

  my $fragment = $fragments[$i - 1];

  my $fragment_path = "${target_directory}/fragment-${i}.wsx";
  my $fragment_evl = "${target_directory}/fragment-${i}.evl";
  my $fragment_miz = "${target_text_subdir}/ckb${i}.miz";

  # Extend the evl of the initial article by inspecting the contents
  # of the prel subdirectory
  opendir (PREL_DIR, $target_prel_subdir)
    or (print ('Error: unable to open the directory at ', $target_prel_subdir, '.', "\n") && exit 1);
  my @prel_files = readdir (PREL_DIR);
  closedir PREL_DIR
    or (print ('Error: unable to close the directory filehandle for ', $target_prel_subdir, '.', "\n") && exit 1);

  my @new_notations = ();
  my @new_registrations = ();
  my @new_definitions = ();
  my @new_theorems = ();
  my @new_schemes = ();
  my @new_constructors = ();

  foreach my $prel_file (@prel_files) {
    my $prel_path = "${target_prel_subdir}/${prel_file}";
    if (-f $prel_path) {
      my $fragment_number = fragment_number ($prel_file);
      my $fragment_article_name_uc = 'CKB' . $fragment_number;
      if ($prel_file =~ /\.dno$/) {
	push (@new_notations, $fragment_article_name_uc);
      }
      if ($prel_file =~ /\.drd$/) {
	push (@new_registrations, $fragment_article_name_uc);
      }
      if ($prel_file =~ /\.dcl$/) {
	push (@new_registrations, $fragment_article_name_uc)
      }
      if ($prel_file =~ /\.eid$/) {
	push (@new_registrations, $fragment_article_name_uc)
      }
      if ($prel_file =~ /\.did$/) {
	push (@new_registrations, $fragment_article_name_uc)
      }
      if ($prel_file =~ /\.sch$/) {
	push (@new_schemes, $fragment_article_name_uc)
      }
      if ($prel_file =~ /\.dco$/) {
	push (@new_constructors, $fragment_article_name_uc)
      }
      if ($prel_file =~ /\.def$/) {
	push (@new_definitions, $fragment_article_name_uc)
      }
      if ($prel_file =~ /\.the$/) {
	push (@new_theorems, $fragment_article_name_uc)
      }
    }
  }

  my $all_notations_token_string = list_as_token_string (\@new_notations);
  my $all_definitions_token_string = list_as_token_string (\@new_definitions);
  my $all_theorems_token_string = list_as_token_string (\@new_theorems);
  my $all_registrations_token_string = list_as_token_string (\@new_registrations);
  my $all_constructors_token_string = list_as_token_string (\@new_constructors);
  my $all_schemes_token_string = list_as_token_string (\@new_schemes);

  my $xsltproc_extend_evl_status
    = system ("xsltproc --output $fragment_evl --stringparam notations '$all_notations_token_string' --stringparam definitions '$all_definitions_token_string' --stringparam theorems '$all_theorems_token_string' --stringparam registrations '$all_registrations_token_string' --stringparam constructors '$all_constructors_token_string' --stringparam schemes '$all_schemes_token_string' $extend_evl_stylesheet $article_evl_in_target_dir 2>/dev/null");
  my $xsltproc_extend_evl_exit_code = $xsltproc_extend_evl_status >> 8;
  if ($xsltproc_extend_evl_exit_code != 0) {
    print 'Error: xsltproc did not exit cleanly when applying the extend-evl stylesheet to ', $article_evl_in_target_dir, '.', "\n";
    exit 1;
  }

  # Now render the fragment's XML as a mizar article
  my $xsltproc_wsm_status
    = system ("xsltproc --output $fragment_miz --stringparam evl '$fragment_evl' $wsm_stylesheet $fragment_path 2>/dev/null");
  my $xsltproc_wsm_exit_code = $xsltproc_wsm_status >> 8;
  if ($xsltproc_wsm_exit_code != 0) {
    print 'Error: xsltproc did not exit cleanly when applying the WSM stylesheet to ', $fragment_path, '.', "\n";
    exit 1;
  }

  if ($paranoid) {
    my $verifier_ok = verify ($fragment_path);
    if ($verifier_ok != 1) {
      print 'Paranoia: fragment number ', $i, ' of ', $article_basename, ' is not verifiable.', "\n";
      exit 1;
    }
  }

  # Now export and transfer the fragment

  my $accom_ok = run_mizar_tool ('accom', $fragment_miz);
  if ($accom_ok == 1) {
    my $verifier_ok = run_mizar_tool ('verifier', $fragment_miz);
    if ($verifier_ok == 1) {
      my $exporter_ok = run_mizar_tool ('exporter', $fragment_miz);
      if ($exporter_ok == 1) {
	my $transfer_ok = run_mizar_tool ('transfer', $fragment_miz);
	if ($transfer_ok != 1) {
	  if ($verbose) {
	    print 'Warning: fragment number ', $i, ' of ', $article_basename, ' is not transferrable.', "\n";
	  }
	}
      } else {
	if ($verbose) {
	  print 'Warning: fragment number ', $i, ' of ', $article_basename, ' is not expotable.', "\n";
	}
      }
    } else {
      if ($verbose) {
	print 'Warning: verifier did not exit cleanly when applied to fragment number ', $i, ' of ', $article_basename, '.', "\n";
      }
    }
  } else {
    if ($verbose) {
      print 'Warning: accom did not exit cleanly when applied to fragment number ', $i, ' of ', $article_basename, '.', "\n";
    }
  }
}

__END__

=pod

=encoding utf8

=head1 NAME

itemize.pl - Divide a mizar article into fragments

=head1 USAGE

itemize.pl [options] mizar-article

=head1 REQUIRED ARGUMENTS

A Mizar article, as a path, must be supplied.

=head1 CONFIGURATION

This program requires that a working Mizar installation is available.
We require these Mizar programs:

=over 8

=item verifier

=item accom

=item msplit

=item mglue

=item exporter

=item transfer

=item wsmparser

=item msmprocessor

=back

The first six are a part of the standard distribution, but wsmparser
and msmprocessor are (as of 2012-01-03) not part of the standard
release.  Please contact the author or the mizar-forum mailing list
(L<mizar-forum@mizar.uwb.edu.pl|mailto:mizar-forum@mizar.uwb.edu.pl>)
to obtain suitable versions of wsmparser and msmprocessor.

=head1 ENVIRONMENT

The MIZFILES environment variable needs to be set to a sensible value.

=head1 DEPENDENCIES

=over 8

=item B<Perl dependencies>

=over 8

=item Cwd

=item File::Basename

=item File::Copy qw(copy);

=item Getopt::Long

=item Pod::Usage

=item XML::LibXML

=back

=item B<XSL dependencies>

This package requires that xsltproc be available.  These stylesheets,
in addition, are required:

=over 8

=item F<split.xsl>

=item F<itemize.xsl>

=item F<wsm.xsl>

=item F<extend-evl.xsl>

=back

If you do not have these stylesheets, see
L<the github page for this program and related Mizar code|https://github.com/jessealama/xsl4mizar/tree/master/items/>
to obtain the latest versions of them.  Use the --stylesheet-home option to
specify the directory in which to look for these needed stylesheets.

=back

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

=item B<--target-directory=DIR>

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

=head1 EXIT STATUS

0 if everything went OK, 1 if any error occurred.  No other exit codes
are used.

=head1 DIAGNOSTICS

Before doing anything, we inspect the MIZFILES environment variable,
and that certain needed Mizar programs are available.  If MIZFILES is
not set, or set to a strange value, we will terminate.  If any of the
needed Mizar programs is not found, we will terminate.

We also check whether the xsltproc XSLT processor is available.  If it
is unavailable, we cannot proceed.

This program, when run with no options on a Mizar article that can be
entirely itemized, will generate no output.  Before itemizing the
article, it is copied to a new directory (whose creation can fail).

The article is then rewritten using various transformations by the
xsltproc XLST processor.  If any of these transformations fails, this
program will terminate and one will learn that some step (which
involves the Mizar accom, verifier, msplit, mglue, wsmparser, and
msmprocessor programs, as well as a handful of XSL stylesheets) has
failed.  At present we do not pass along whatever error messages
xsltproc generated, nor do we explain any Mizar error files.  If a
Mizar program fails, you can see for yourself how it failed by
consulting the .err file corresponding to the failing .err file; see
also the file F<mizar.msg> under the MIZFILES environment variable.

=head1 BUGS AND LIMITATIONS

Sending a signal to this program when it is writing out the fragments
of the initial article and running accom/verifier/exporter/transfer
should probably kill the whole process.  Instead, it kills
accom/verifier/exporter/transfer, and itemization continues in an
incoherent state.

There are some opportunities for parallelization of the itemization
process, but at the moment we are not exploiting these.

=head1 INCOMPATIBILITIES

None known.

=head1 AUTHOR

Jesse Alama <jesse.alama@gmail.com>

=head1 LICENSE AND COPYRIGHT

This source is offered under the terms of
L<the GNU GPL version 3|http://www.gnu.org/licenses/gpl-3.0.en.html>.

=cut
