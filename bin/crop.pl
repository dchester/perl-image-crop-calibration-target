use strict;

use Crop;
use File::Slurp qw(read_file write_file);

opendir(my $dh, "public/original") || die; 

my $counter = 0;

while (readdir $dh) {

	next if $_ =~ m/^\./;
	next if $_ !~ m/\.jpg$/i;

	next if ++$counter < 763;

	my $name = $_;

	my $filename = "public/original/$_";

	print "$filename $counter\n";

	my $image_data = read_file($filename, { binmode => 'raw' });

	eval {

		my $crop = Crop->new(
			image_data => $image_data,
		);

		my $image_data = $crop->image_data;

		if ($crop->cropped) {
			print "cropped!\n";
			my $cropped_filename = "public/cropped/$name";
			print "CR $cropped_filename\n";
			write_file($cropped_filename, { binmode => 'raw' }, $image_data);
		}
	};

	die $@ if $@;

}

__END__



write_file('/tmp/out.jpg', { binmode => 'raw' }, $image_data);

print "cropped.\n" if $crop->cropped;


