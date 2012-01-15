#!/usr/bin/perl -w

use strict;
use File::Basename qw(basename dirname);
use XML::LibXML;
use POSIX qw(floor ceil);
use Getopt::Long;
use Pod::Usage;
use Cwd qw(cwd);
use File::Copy qw(copy move);

my $paranoid = 0;
my $verbose = 0;
my $man = 0;
my $help = 0;
my $confirm_only = 0;
my $stylesheet_home = '/Users/alama/sources/mizar/xsl4mizar/items';
my $script_home = '/Users/alama/sources/mizar/xsl4mizar/items';
my $target_directory = undef;

GetOptions('help|?' => \$help,
           'man' => \$man,
           'verbose'  => \$verbose,
	   'paranoid' => \$paranoid,
	   'stylesheet-home=s' => \$stylesheet_home,
	   'script-home=s' => \$script_home,
	   'target-directory=s' => \$target_directory)
  or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

pod2usage(1) unless (scalar @ARGV == 1);

######################################################################
## Ensure validity of commandline arguments
######################################################################

unless (-e $stylesheet_home) {
  die 'Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets does not exist.';
}

unless (-d $stylesheet_home) {
  die 'Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.';
}

my %stylesheet_paths =
  ('truncate' => "${stylesheet_home}/truncate.xsl",
   'toplevel-propositions' => "${stylesheet_home}/toplevel-propositions.xsl",
   'skip-non-ultimate-proofs' => "${stylesheet_home}/skip-non-ultimate-proofs.xsl",
   'lemma-deps' => "${stylesheet_home}/lemma-deps.xsl",
   'dependencies' => "${stylesheet_home}/dependencies.xsl",
   'inferred-constructors' => "${stylesheet_home}/inferred-constructors.xsl",
   'rewrite-aid' => "${stylesheet_home}/rewrite-aid.xsl");

sub path_for_stylesheet {
  my $sheet = shift;
  if (defined $stylesheet_paths{$sheet}) {
    return $stylesheet_paths{$sheet};
  } else {
    croak ('Error: We were asked for the path of the ', $sheet, ' stylesheet, but it could not be found.');
  }
}

my $absrefs_stylesheet = path_for_stylesheet ('absrefs');
my $truncate_stylesheet = path_for_stylesheet ('truncate');
my $toplevel_propositions_stylesheet = path_for_stylesheet ('toplevel-propositions');
my $skip_non_ultimate_proofs_stylesheet = path_for_stylesheet ('skip-non-ultimate-proofs');
my $inferred_constructors_stylesheet = path_for_stylesheet ('inferred-constructors');
my $lemma_deps_stylesheet = path_for_stylesheet ('lemma-deps');
my $external_deps_stylesheet = path_for_stylesheet ('dependencies');
my $rewrite_aid_stylesheet = path_for_stylesheet ('rewrite-aid');

foreach my $stylesheet (keys %stylesheet_paths) {
  my $stylesheet_path = path_for_stylesheet ($stylesheet);
  unless (-e $stylesheet_path) {
    die 'Error: the ', $stylesheet, ' stylesheet does not exist at the expected location (', $stylesheet_path, ').';
  }
  unless (-r $stylesheet_path) {
    die 'Error: the ', $stylesheet, ' stylesheet at ', $stylesheet_path, ' is unreadable.';
  }
}

unless (-e $script_home) {
  die 'Error: the supplied directory', "\n", "\n", '  ', $script_home, "\n", "\n", 'in which we look for scripts does not exist.';
}

unless (-d $script_home) {
  die 'Error: the supplied directory', "\n", "\n", '  ', $script_home, "\n", "\n", 'in which we look for scripts is not actually a directory.';
}

my $brutalize_script = "${script_home}/minimal.pl";
my $brutalize_internally_script = "${script_home}/minimize-internally.pl";

if (! -e $brutalize_script) {
  die 'Error: the minimization script could not be found at the expected location (', $brutalize_script, ').';
}

if (! -f $brutalize_script) {
  die 'Error: the minimization script at ', $brutalize_script, ' is not a file.';
}

if (! -r $brutalize_script) {
  die 'Error: the minimization script at ', $brutalize_script, ' is not readable.';
}

if (! -x $brutalize_script) {
  die 'Error: the minimization script at ', $brutalize_script, ' is not executable.';
}

if (! -e $brutalize_internally_script) {
  die 'Error: the minimization script could not be found at the expected location (', $brutalize_internally_script, ').';
}

if (! -f $brutalize_internally_script) {
  die 'Error: the minimization script at ', $brutalize_internally_script, ' is not a file.';
}

if (! -r $brutalize_internally_script) {
  die 'Error: the minimization script at ', $brutalize_internally_script, ' is not readable.';
}

if (! -x $brutalize_internally_script) {
  die 'Error: the minimization script at ', $brutalize_internally_script, ' is not executable.';
}

my $article = $ARGV[0];
my $article_basename = basename ($article, '.miz');
my $article_dirname = dirname ($article);
my $article_sans_extension = "${article_dirname}/${article_basename}";

if (defined $target_directory) {
  if (-e $target_directory) {
    die 'Error: the supplied target directory, ', $target_directory, ' already exists.  Please move it out of the way.';
  } else {
    mkdir $target_directory
      or die 'Error: unable to make the directory \'', $target_directory, '\'.';
  }
} else {
  my $cwd = cwd ();
  $target_directory = "${cwd}/${article_basename}";
  if (-e $target_directory) {
    die 'Error: since the target-directory option was not used, we are to save our wok in \'', $article_basename, '\'; but there is already a directory by that name in the current working directory.  Please move it out of the way.';
    exit 1;
  }
  mkdir $target_directory
    or die 'Error: unable to make the directory \'', $article_basename, '\' in the current working directory.';
}

# Copy the article

my $article_miz = "${article_dirname}/${article_basename}.miz";

if (! -e $article_miz) {
  die 'Error: ', $article_miz, ' does not exist.';
}

if (! -r $article_miz) {
  die 'Error: ', $article_miz, ' is unreadable.';
}

my $article_err_in_target_dir = "${target_directory}/${article_basename}.err";
my $article_miz_in_target_dir = "${target_directory}/${article_basename}.miz";

copy ($article_miz, $article_miz_in_target_dir)
  or die 'Error: unable to copy the article at ', $article_miz, ' to ', $article_miz_in_target_dir, '.';

chdir $target_directory;

my $accom_status = system ("accom -l -q $article_miz_in_target_dir > /dev/null 2>&1");
my $accom_exit_code = $accom_status >> 8;
if ($accom_exit_code != 0) {
  die 'Error: unable to accommodate ', $article_basename, ' in the target directory (', $target_directory, ').';
}

my $verifier_status = system ("verifier -l -q $article_miz_in_target_dir > /dev/null 2>&1");
my $verifier_exit_code = $verifier_status >> 8;
if ($verifier_exit_code != 0) {
  die 'Error: unable to verify ', $article_basename, ' in the target directory (', $target_directory, ').';
}

if (! -z $article_err_in_target_dir) {
  die 'Error: verifier produced a non-empty error file for ', $article_basename, ' in the target directory (', $target_directory, ').';
}

my $article_xml_in_target_dir = "${target_directory}/${article_basename}.xml";
my $article_absolute_xml_in_target_dir = "${target_directory}/${article_basename}.xml1";

if (! -e $article_xml_in_target_dir) {
  die 'Error: verifier did not produce a semantic XML representation of ', $article_basename, '.';
}

foreach my $extension ('xml', 'eno', 'dfs', 'ecl', 'eid', 'epr', 'erd', 'esh', 'eth') {
  my $source_xml_file = "${target_directory}/${article_basename}.${extension}";
  my $target_xml_file = "${target_directory}/${article_basename}.${extension}1";
  if (-e $source_xml_file) {
    my $xsltproc_absrefs_status = system ("xsltproc --output $target_xml_file $absrefs_stylesheet $source_xml_file 2>/dev/null");
    my $xsltproc_absrefs_exit_code = $xsltproc_absrefs_status >> 8;
    if ($xsltproc_absrefs_exit_code != 0) {
      die 'Error: xsltproc did not exit cleanly when computing the absolute form of ', $article_basename, '.', $extension, '; its exit code was ', $xsltproc_absrefs_exit_code, '.';
    }
  }
}

my @elements_and_propositions = `xsltproc $toplevel_propositions_stylesheet $article_absolute_xml_in_target_dir 2>/dev/null`;
chomp @elements_and_propositions;

my %propositions_for_element = ();
my %element_for_proposition = ();

foreach my $element_and_proposition (@elements_and_propositions) {
  (my $element_position, my @generated_propositions)
    = split (/ /, $element_and_proposition);
  if (defined $element_position) {
    if (scalar @generated_propositions == 0) {
      die 'Error: unable to parse the line \'', $element_and_proposition, '\' coming from the application of the toplevel-propositions stylesheet to the absolute XML representation of ', $article_basename, '.';
    } else {
      $propositions_for_element{$element_position} = \@generated_propositions;
      foreach my $prop (@generated_propositions) {
	$element_for_proposition{$prop} = $element_position;
      }
    }
  } else {
    die 'Error: unable to parse the line \'', $element_and_proposition, '\' coming from the application of the toplevel-propositions stylesheet to the absolute XML representation of ', $article_basename, '.';
  }
}

opendir (DIR, $target_directory)
  or die 'Error: unable to open the target directory at ', $target_directory, '.';
my @mizar_generated_files = readdir DIR;
closedir DIR
  or die 'Error: unable to close the directory at ', $target_directory, '.';

sub extension {
  my $path = shift;
  if ($path =~ /[.]([^.]+)$/) {
    return $1;
  } else {
    die 'Error: the path \'', $path, '\' does not have an extension.';
  }
}

foreach my $lemma (keys %element_for_proposition) {
  foreach my $mizar_file (@mizar_generated_files) {
    # watch out for the files '.' and '..'
    if (-f $mizar_file) {
      my $ext = extension ($mizar_file);
      my $lemma_file = "${lemma}.${ext}";
      copy ($mizar_file, $lemma_file)
	or die 'Error: unable to copy the original Mizar file ', $mizar_file, ' to its lemma clone ', $lemma_file, '.';
    }
  }
}

# Now truncate each of the XML files

foreach my $lemma (keys %element_for_proposition) {
  my $lemma_position = $element_for_proposition{$lemma};
  my $lemma_xml = "${lemma}.xml";
  my $lemma_xml_temp = "${lemma}.xml.tmp";

  my $xsltproc_truncate_status = system ("xsltproc --output '$lemma_xml_temp' --stringparam after '$lemma_position' $truncate_stylesheet $lemma_xml 2>/dev/null");
  my $xsltproc_truncate_exit_code = $xsltproc_truncate_status >> 8;
  if ($xsltproc_truncate_exit_code != 0) {
    die 'Error: xsltproc did not exit cleanly when applying the truncate stylesheet to ', $lemma_xml, '.';
  }
  move ($lemma_xml_temp, $lemma_xml)
    or die 'Error: unable to move the temporary lemma XML at ', $lemma_xml_temp, ' to ', $lemma_xml, '.';
}

# If we're in paranoid mode, check that new XML is verifiable
if ($paranoid) {
  if ($verbose) {
    print 'Paranoia: checking that the truncated articles are verifiable...';
  }
  foreach my $lemma (keys %element_for_proposition) {
    my $lemma_miz = "${lemma}.miz";
    my $lemma_err = "${lemma}.err";
    my $verifier_status = system ("verifier -c $lemma > /dev/null 2>&1");
    my $verifier_exit_code = $verifier_status >> 8;
    if ($verifier_exit_code != 0 || ! -z $lemma_err) {
      if ($verbose) {
	print "\n";
      }
      die 'Error: lemma ', $lemma, ' is not verifiable!';
    }
  }
  if ($verbose) {
    print 'done.', "\n";
  }
}

# For each of the truncated XML files, skip all proofs that aren't
# part of the final element

foreach my $lemma (keys %element_for_proposition) {
  my $lemma_xml = "${lemma}.xml";
  my $lemma_xml_temp = "${lemma}.xml.tmp";

  my $xsltproc_skip_status = system ("xsltproc --output '$lemma_xml_temp' $skip_non_ultimate_proofs_stylesheet $lemma_xml");
  my $xsltproc_skip_exit_code = $xsltproc_skip_status >> 8;
  if ($xsltproc_skip_exit_code != 0) {
    die 'Error: xsltproc did not exit cleanly when applying the skip-proofs stylesheet to ', $lemma_xml, '.';
  }
  move ($lemma_xml_temp, $lemma_xml)
    or die 'Error: unable to move the temporary lemma XML at ', $lemma_xml_temp, ' to ', $lemma_xml, '.';
}

# If we're in paranoid mode, check that new XML is verifiable
if ($paranoid) {
  warn 'Checking skip-proof process...';
  foreach my $lemma (keys %element_for_proposition) {
    my $lemma_miz = "${lemma}.miz";
    my $lemma_err = "${lemma}.err";
    my $verifier_status = system ("verifier -c $lemma_miz > /dev/null 2>&1");
    my $verifier_exit_code = $verifier_status >> 8;
    if ($verifier_exit_code != 0 || ! -z $lemma_err) {
      die 'Error: lemma ', $lemma, ' is not verifiable after skipping all proofs preceding it!';
    }
  }
}

# Minimize the article "internally": delete as many of the toplevel
# nodes preceding the final node as possible
if ($verbose) {
  print 'Minimizing the fragments internally...';
}
foreach my $lemma (keys %element_for_proposition) {
  my $lemma_miz = "${lemma}.miz";
  my $lemma_err = "${lemma}.err";
  my $lemma_deletable_indices = "${lemma}.deletable-indices";
  my $minimize_status = system ("$brutalize_internally_script $lemma_miz > $lemma_deletable_indices 2>&1");
  my $minimize_exit_code = $minimize_status >> 8;
  if ($minimize_exit_code != 0) {
    if ($verbose) {
      print "\n";
    }
    die 'Error: lemma ', $lemma, ' could not be minimized internally.';
  }
}
if ($verbose) {
  print 'done.', "\n";
}

# Brutalize the environment of the fragments
if ($verbose) {
  print 'Minimizing the environments of the fragments...';
}
foreach my $lemma (keys %element_for_proposition) {
  my $lemma_miz = "${lemma}.miz";
  my $lemma_err = "${lemma}.err";
  my $minimize_call = undef;
  if ($verbose) {
    $minimize_call = "$brutalize_script --verbose --checker-only $lemma_miz 2>&1"
  } else {
    $minimize_call = "$brutalize_script --checker-only $lemma_miz 2>&1"
  }
  my $minimize_status = system ($minimize_call);
  my $minimize_exit_code = $minimize_status >> 8;
  if ($minimize_exit_code != 0) {
    if ($verbose) {
      print "\n";
    }
    die 'Error: lemma ', $lemma, ' could not be minimized.';
  }
}
if ($verbose) {
  print 'done.', "\n";
}

# Absolutize the fragments
foreach my $lemma (keys %element_for_proposition) {
  foreach my $extension ('xml', 'eno', 'dfs', 'ecl', 'eid', 'epr', 'erd', 'esh', 'eth') {
    my $source_xml_file = "${lemma}.${extension}";
    my $target_xml_file = "${lemma}.${extension}1";
    if (-e $source_xml_file) {
      my $xsltproc_absrefs_status = system ("xsltproc --output $target_xml_file $absrefs_stylesheet $source_xml_file 2>/dev/null");
      my $xsltproc_absrefs_exit_code = $xsltproc_absrefs_status >> 8;
      if ($xsltproc_absrefs_exit_code != 0) {
	die 'Error: xsltproc did not exit cleanly when computing the absolute form of ', $article_basename, '.', $extension, '.';
      }
    }
  }
}

my %deps_for_lemmas = ();

if ($verbose) {
  print 'Gathering article-internal dependencies...';
}

# Gather the article-internal dependencies
foreach my $lemma (keys %element_for_proposition) {
  my $lemma_mptp_name = "${lemma}_${article_basename}";
  my $lemma_xml = "${lemma}.xml";
  my $lemma_abs_xml = "${lemma}.xml1";
  my $lemma_deps_file = "${lemma}.deps.internal";
  my $lemma_deps_file_errors = "${lemma}.deps.internal.errors";
  my $lemma_deps_file_tmp = "${lemma}.deps.internal.tmp";
  my $xsltproc_lemma_deps_status = system ("xsltproc $lemma_deps_stylesheet $lemma_abs_xml > $lemma_deps_file_tmp 2> $lemma_deps_file_errors");
  my $xsltproc_lemma_deps_exit_code = $xsltproc_lemma_deps_status >> 8;
  if ($xsltproc_lemma_deps_status != 0) {
    if ($verbose) {
      print "\n";
    }
    die 'Error: xsltproc did not exit cleanly applying the lemma-dependencies stylesheet to ', $lemma, '.';
  }
  my $tr_status = system ("tr -s '\n' < $lemma_deps_file_tmp > $lemma_deps_file");
  my $tr_exit_code = $tr_status >> 8;
  if ($tr_exit_code != 0) {
    die 'Error: tr died cleaning up our junky article-internal dependency list at ', $lemma_deps_file_tmp, '.';
  }
  unlink $lemma_deps_file_tmp
    or die 'Error: unable to delete our temprary junky article-internal dependency list at ', $lemma_deps_file_tmp, '.';
  my @lemma_deps = `cat $lemma_deps_file | sort -u`;
  chomp @lemma_deps;
  foreach my $lemma_dep (@lemma_deps) {
    $deps_for_lemmas{$lemma}{$lemma_dep} = 0;
  }
}

# We need to rewrite the aid of the article; otherwise the external
# dependencies stylesheet will sniff through the original whole article
foreach my $lemma (keys %element_for_proposition) {
  my $lemma_abs_xml = "${lemma}.xml1";
  my $lemma_abs_xml_tmp = "${lemma}.xml1.tmp";
  my $xsltproc_rewrite_aid_status = system ("xsltproc --stringparam new-aid '${lemma}' $rewrite_aid_stylesheet $lemma_abs_xml > $lemma_abs_xml_tmp 2> /dev/null");
  my $xsltproc_rewrite_aid_exit_code = $xsltproc_rewrite_aid_status >> 8;
  if ($xsltproc_rewrite_aid_status != 0) {
    if ($verbose) {
      print "\n";
    }
    die 'Error: xsltproc did not exit cleanly applying aid-rewriting stylesheet to ', $lemma, '.';
  }
  move ($lemma_abs_xml_tmp, $lemma_abs_xml)
    or die 'Error: unable to rename ', $lemma_abs_xml_tmp, ' to ', $lemma_abs_xml, '.';
}

# Inferred constructors
foreach my $lemma (keys %element_for_proposition) {
  my $lemma_mptp_name = "${lemma}_${article_basename}";
  my $lemma_abs_xml = "${lemma}.xml1";
  my $lemma_deps_errors = "${lemma}.inferred-constructors.errors";
  my $lemma_deps_file = "${lemma}.inferred-constructors";
  my $lemma_deps_file_tmp = "${lemma}.inferred-constructors.tmp";
  my $xsltproc_lemma_deps_status = system ("xsltproc $inferred_constructors_stylesheet $lemma_abs_xml > $lemma_deps_file_tmp 2> $lemma_deps_errors");
  my $xsltproc_lemma_deps_exit_code = $xsltproc_lemma_deps_status >> 8;
  if ($xsltproc_lemma_deps_status != 0) {
    if ($verbose) {
      print "\n";
    }
    die 'Error: xsltproc did not exit cleanly applying the inferred-constructors stylesheet to ', $lemma, '.';
  }
  my $sort_status = system ("sort -u $lemma_deps_file_tmp > $lemma_deps_file");
  my $sort_exit_code = $sort_status >> 8;
  if ($sort_exit_code != 0) {
    die 'Error: sort did not exit cleanly when sorting the inferred constructor list.';
  }
  unlink $lemma_deps_file_tmp
    or die 'Error: unable to delete the temporary inferred constructors file.';
  my @lemma_deps = `cat $lemma_deps_file`;
  chomp @lemma_deps;
  foreach my $lemma_dep (@lemma_deps) {
    $deps_for_lemmas{$lemma}{$lemma_dep} = 0;
  }
}

if ($verbose) {
  print 'done.', "\n";
}

if ($verbose) {
  print 'Gathering article-external dependencies...';
}

# Gather the envrionment (article-external) dependencies
foreach my $lemma (keys %element_for_proposition) {
  my $lemma_abs_xml = "${lemma}.xml1";
  my $lemma_deps_file = "${lemma}.deps.external";
  my $lemma_deps_file_errors = "${lemma}.deps.external.errors";
  my $xsltproc_lemma_deps_status = system ("xsltproc $external_deps_stylesheet $lemma_abs_xml > $lemma_deps_file 2> $lemma_deps_file_errors");
  my $xsltproc_lemma_deps_exit_code = $xsltproc_lemma_deps_status >> 8;
  if ($xsltproc_lemma_deps_status != 0) {
    if ($verbose) {
      print "\n";
    }
    die 'Error: xsltproc did not exit cleanly applying the external (envrironment) dependencies stylesheet to ', $lemma, '.';
  }
  my @lemma_deps = `cat $lemma_deps_file`;
  chomp @lemma_deps;
  foreach my $lemma_dep (@lemma_deps) {
    $deps_for_lemmas{$lemma}{$lemma_dep} = 0;
  }
}

if ($verbose) {
  print 'done.', "\n";
}

# Print everything

foreach my $lemma (keys %element_for_proposition) {
  my $mptp_lemma_name = "${lemma}_${article_basename}";
  print $mptp_lemma_name;
  if (defined $deps_for_lemmas{$lemma}) {
    my @deps = keys %{$deps_for_lemmas{$lemma}};
    foreach my $dep (@deps) {
      print ' ', $dep;
    }
  }
  print "\n";
}


__END__

=cut

=head1 minimize-lemmas.pl

minimize-lemmas.pl - Minimize the article-internal context of the lemmas of a Mizar article

=head1 SYNOPSIS

minimize-lemmas.pl [options] mizar-article

Options:
  -help                       Brief help message
  -man                        Full documentation
  -verbose                    Say what we're doing

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<minimize-lemmas.pl> will construct, given a Mizar article, the
smallest article-internal environment with respect to which the lemmas
of the Mizar article are verifiable.

=cut
