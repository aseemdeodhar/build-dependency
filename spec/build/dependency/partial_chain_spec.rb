# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

RSpec.describe Build::Dependency::PartialChain do
	describe "app chain" do
		include_context "app packages"
		
		let(:chain) {Build::Dependency::Chain.expand(['app', 'lib'], packages)}
		
		it "should generate full list of ordered providers" do
			expect(chain.ordered).to be == [
				Build::Dependency::Resolution.new(variant, Build::Dependency::Target.new('Variant/debug')),
				Build::Dependency::Resolution.new(platform, Build::Dependency::Target.new('Platform/linux')),
				Build::Dependency::Resolution.new(compiler, Build::Dependency::Target.new("Language/C++17")),
				Build::Dependency::Resolution.new(lib, Build::Dependency::Target.new('lib')),
				Build::Dependency::Resolution.new(app, Build::Dependency::Target.new('app')),
			]
		end
		
		it "should generate a full list of provisions" do
			expect(chain.provisions).to be == [
				variant.provision_for(Build::Dependency::Target['Variant/debug']),
				platform.provision_for(Build::Dependency::Target['Platform/linux']),
				compiler.provision_for(Build::Dependency::Target['Language/C++17']),
				lib.provision_for(Build::Dependency::Target.new('lib')),
				compiler.provision_for(Build::Dependency::Target['Language/C++14']),
				app.provision_for(Build::Dependency::Target.new('app')),
			]
			
			graph = visualization.generate(chain)
			
			Graphviz::output(graph, path: "app-chain-full.pdf")
		end
		
		subject {described_class.new(chain, app.targets)}
		
		it "should select app packages" do
			expect(subject.ordered).to be == [
				Build::Dependency::Resolution.new(variant, Build::Dependency::Target.new('Variant/debug')),
				Build::Dependency::Resolution.new(platform, Build::Dependency::Target.new('Platform/linux')),
				Build::Dependency::Resolution.new(lib, Build::Dependency::Target.new('lib')),
				Build::Dependency::Resolution.new(compiler, Build::Dependency::Target.new("Language/C++14")),
			]
			
			graph = visualization.generate(subject)
			
			Graphviz::output(graph, path: "app-chain-partial.pdf")
		end
	end
	
	describe "private targets" do
		let(:a) do
			Package.new('a').tap do |package|
				package.provides 'a'
			end
		end
		
		let(:b) do
			Package.new('b').tap do |package|
				package.provides 'b'
				package.depends 'a', private: true
			end
		end
		
		let(:c) do
			Package.new('c').tap do |package|
				package.provides 'c'
				package.depends 'b'
			end
		end
		
		let(:d) do
			Package.new('d').tap do |package|
				package.provides 'd'
				package.depends 'c'
			end
		end
		
		let(:chain) {Build::Dependency::Chain.expand(['d'], [a, b, c, d])}
		
		it "should include direct private dependencies" do
			partial_chain = chain.partial(b)
			
			expect(partial_chain.ordered.collect(&:first)).to be == [a]
		end
		
		it "shouldn't include nested private dependencies" do
			partial_chain = chain.partial(c)
			
			expect(partial_chain.ordered.collect(&:first)).to be == [b]
		end
		
		it "should follow non-private dependencies" do
			partial_chain = chain.partial(d)
			
			expect(partial_chain.ordered.collect(&:first)).to be == [b, c]
		end
	end
end
