use Dancer;
use Dancer::Template::TemplateToolkit;

get '/' => sub {

	my $page = param('page') || 0;
	my $page_size = 1000;

	my @images;

	opendir(my $dh, "public/orig") || die;

	while (readdir $dh) {
		next unless $_ =~ m/jpg$/;
		my $cropped = -e "public/crop/$_" ? 1 : 0;
		my $crop_dir = $cropped ? 'crop' : 'orig';
		push @images, {
			orig_filename => "orig/$_",
			crop_filename => "$crop_dir/$_",
			cropped_class => $crop_dir
		};
	}

	@images = splice @images, $page * $page_size, $page * $page_size + $page_size;

	template 'images.html', { images => \@images };
};

dance;
