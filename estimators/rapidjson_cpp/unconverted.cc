#include "rapidjson/document.h"
#include "rapidjson/prettywriter.h"
#include "rapidjson/filestream.h"
#include <cstdio>
#include <string>
#include <fstream>
#include <streambuf>
#include <sstream>
#include <limits.h>
#include <iostream>
#include <ctime>
#include <unordered_map>
#include <stdio.h>

using namespace rapidjson;
using namespace std;

int main() {
    FILE * udon;
    udon = fopen("udon.csv","w");
    clock_t fc=0,jc=0,lc=0,oc=0;
    long int cnt=0;
    long int cnt_all=0;
    string key="うどん";
    unordered_map<string,int> all;
    unordered_map<string,int> word;

    for (int j=0; j<50; j++){
    clock_t t1 = clock();
    stringstream js;
    js << j;
    string filename = "/home/chinbat/analysis/clean_files/twout"+js.str()+"/twout"+js.str()+"_edited.json";
    ifstream t(filename);
    stringstream buffer;

    buffer << t.rdbuf()<<endl;
    clock_t t2 = clock();
    fc += t2-t1;
    rapidjson::Document d;
    d.Parse<0>(buffer.str().c_str());
    const Value& a = d["tweets"];
    assert(a.IsArray());
    clock_t t3 = clock();
    jc += t3-t2; 
    for(SizeType i = 0; i < a.Size(); i++){
        cnt_all++;
        const Value& tweet = a[i];
        assert(tweet.IsObject());
	string coordinate = tweet["coordinates"].GetString();
        coordinate.erase(coordinate.size()-1);
        coordinate.erase(0,1);
	int comma = coordinate.find(",");
	string latitude = coordinate.substr(0,comma);
	string longitude = coordinate.substr(comma+1,coordinate.size()-comma-1);
	double lati = atof(latitude.c_str());
	double longi = atof(longitude.c_str());
	int nlat = (lati-21.94)/0.02314;
	int nlong = (longi-123.75)/0.0225;
	double rlat = nlat*0.02314 + 21.94+0.02314/2;
	double rlong = nlong*0.0225 + 123.75 + 0.0225/2;
	stringstream sslat,sslong;
	sslat << rlat;
	sslong << rlong;
	coordinate = sslat.str() + "," + sslong.str();
	auto get_all = all.find(coordinate);
        if(get_all == all.end()){
		all[coordinate]=1;
	}else{
		get_all->second += 1;
	}

	string text = tweet["text"].GetString();
	if (text.find(key) != -1){
		auto got = word.find(coordinate);
		if ( got == word.end()){
	    		word[coordinate]=1;
		}else{
	    		got->second += 1;
		}
        	cnt++;
	}
    }
    clock_t t4 = clock();
    lc += t4-t3;
    } // end for loop j
    clock_t t5 = clock();
    for(auto it = word.begin();it!=word.end();++it){
        string tmp = it->first;
        int num = it->second;
        int num_all = all[tmp];
        fprintf(udon,"%s,%d,%d\n",tmp.c_str(),num,num_all);
    }
    clock_t t6 = clock();
    oc = t6-t5;
    cout<<"File: "<<(double)fc/CLOCKS_PER_SEC<<endl;
    cout<<"JSON: "<<(double)jc/CLOCKS_PER_SEC<<endl;
    cout<<"Loops: "<<(double)lc/CLOCKS_PER_SEC<<endl;
    cout<<"Output: "<<(double)oc/CLOCKS_PER_SEC<<endl<<endl;
    cout<<"all tweets: "<<cnt_all<<endl;
    cout<<"udon tweets: "<<cnt<<endl;
    cout<<"different coordinates: "<<word.size()<<endl;
    return 0;
}
