use strict;

use Image::Crop::CalibrationTarget;
use File::Slurp qw(read_file write_file);

my $input_dir = shift @ARGV;
my $output_dir = shift @ARGV;

opendir(my $dh, $input_dir) || die $!;

while (readdir $dh) {

	next if $_ =~ m/^\./;

	my $name = $_;

	my $filename = "$input_dir/$_";

	print "$filename\n";

	my $image_data = read_file($filename, { binmode => 'raw' });

	eval {

		my $crop = Image::Crop::CalibrationTarget->new( image_data => $image_data );

		my $image_data = $crop->image_data;

		if ($crop->cropped) {
			print "cropped!\n";
			my $cropped_filename = "$output_dir/$name";
			write_file($cropped_filename, { binmode => 'raw' }, $image_data);
		}
	};

	die $@ if $@;
}

