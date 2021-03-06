#include <bits/stdc++.h>
#include <windows.h>
#include <experimental/filesystem>

#define ll long long int
#define ld long double
#define X first
#define Y second
#define upn(x, init, n) for (int x = init; x <= n; ++x)
#define upiter(x, container) for (auto x = container.begin(); x != container.end(); ++x)
#define dn(x, init, n) for(int x = init; x >= n; --x)
#define diter(x, container) for (auto x = container.rbegin(); x != container.rend(); ++x)
#define pb push_back
#define pii pair<ll, ll>
#define el '\n'
#define sfio() freopen("input.txt", "r", stdin); freopen("output.txt", "w", stcout);
#define PI acos(-1.0)
#define eps 0.000000001
#define mod 1000000007
#define mp make_pair
#define NF string::npos

using namespace std;
namespace fs = std::experimental::filesystem;
bool adjustId = false;

string tmp, modIdPrefix;
fs::path workDir, speechDir, speechExtraDir, stringsDir, stringsVanillaFile, scenesDir;
vector<string> sceneYmls;
vector< pair<int, pair<string, string>> > adjustLines;
/*           old     new      */
vector<string> addToCustomCsv, missedSpeech;
set<string> hasSpeech;
map<string, string> durById;
map<string, pair<string, string>> lineInfo, lineInfo2;
/*    id      duration    str      */
map<string, string> idByStr;

ofstream dbgout;

enum consoleColor {
    ccBLACK, ccDARKBLUE, ccDARKGREEN, ccDARKCYAN, ccDARKRED, ccDARKVIOLET, ccDARKYELLOW, ccDARKWHITE,
    ccGRAY, ccBLUE, ccGREEN, ccCYAN, ccRED, ccVIOLET, ccYELLOW, ccWHITE
};
void setConsoleColor(int type) {
    SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), type);
    // you can loop k higher to see more color choices
    /*for(int k = 1; k < 255; k++)    {
    // pick the colorattribute k you want
        SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), k);
        cout << k << " have a nice day!\n";
    }*/
}
void loadMainCsv(fs::path p, bool forceAdjustIds = false) {
    ifstream csv(p.u8string());
    while (!csv.eof()) {
        getline(csv, tmp);
        if (tmp.empty() || !isdigit(tmp[0])) {
            continue;
        }
        int pos = 0;
        int sepCnt = 0;
        string id = "";
        string str = "";
        while (isdigit(tmp[pos]) && pos < tmp.length()) {
            id.push_back(tmp[pos]);
            ++pos;
        }
        while (sepCnt < 3 && pos < tmp.length()) {
            if (tmp[pos] == '|') {
                ++sepCnt;
            }
            ++pos;
        }
        str = tmp.substr(pos, tmp.length() - pos);
        //cout << ">> id: " << id << ", str: [" << str << "]\n";
        if (durById.count(id) > 0) {
            lineInfo[id] = {durById[id], str};
            idByStr[str] = id;
        } else if (forceAdjustIds) {
            lineInfo[id] = {"-1", str};
            idByStr[str] = id;
        }
    }
    csv.close();
}
void tryAddDuration(fs::path p) {
    tmp = p.stem().u8string();

    string id = tmp.substr(0, 10);
    for (auto c : id) {
        if (!isdigit(c)) {
			setConsoleColor(6);
            cout << "    [" << p.filename().u8string() << "] does not contain correct id in name! Skipped\n";
			setConsoleColor(7);
            return;
        }
    }
    string duration = "";
    int add = 0;
    upn(i, 0, tmp.length() - 1) {
        if (tmp[i] == ']')
            ++add;
        if (add == 1)
            duration.pb(tmp[i]);
        if (tmp[i] == '[')
            ++add;
    }
    for (auto c : duration) {
        if (!isdigit(c) && c != '.') {
			setConsoleColor(6);
            cout << "    [" << p.filename().u8string() << "] does not contain correct duration in name! Skipped\n";
			setConsoleColor(7);
            return;
        }
    }
    /*if (lineInfo[id].X != "-1") {
		setConsoleColor(6);
        cout << "    Warning! Override duration of " << p.filename().u8string() << ", old = [";
		setConsoleColor(7);
        cout << lineInfo[id].X << "], new = [" << duration << "]\n";
    }*/
    //cout << "[OK] id = " << id << ", duration = " << duration << el;
    durById[id] = duration;
    lineInfo[id].X = duration;
    //hasSpeech.insert(id);

    //dbgout << id << el;
}
/*void removeWithoutDuration() {
    lineInfo2 = lineInfo;
    lineInfo.clear();
    for (auto it = lineInfo2.begin(); it != lineInfo2.end(); ++it) {
        if (it->Y.X == "-1") {
            setConsoleColor(4);
            cout << it->Y.Y << "\n";
            setConsoleColor(7);
            if (idByStr.find(it->X) != idByStr.end())
                idByStr.erase(idByStr.find(it->X));
        } else {
            setConsoleColor(2);
            cout << it->Y.Y << "\n";
            setConsoleColor(7);
            lineInfo.insert(*it);
        }
    }
}*/
string formatLine(string prefix, string suffix, string id, bool hadId) {
    string newLine = prefix + "\"";
    if (lineInfo[id].X != "-1") {
        newLine += "[" + lineInfo[id].X + "]";
    }
    if (hadId || adjustId)
        newLine += id + "|";
    //cout << "str: " << lineInfo[id].Y << el;
    newLine += lineInfo[id].Y + suffix;
    return newLine;
}
void tryAdjustLines(fs::path p) {
    ifstream yml(p.u8string());
    adjustLines.clear();
    addToCustomCsv.clear();
    //missedSpeech.clear();
    bool dialogscript = false;
    bool section = false;
    bool choice = false;
    int cntLine = 0;
    int cntLine2 = 0;

    while (!yml.eof()) {
        getline(yml, tmp);
        ++cntLine;
        if (tmp.find("dialogscript:") != NF)
            dialogscript = true;
        if (tmp.find("section_") != NF) {
            section = true;
        }
        if (tmp.find("SCRIPT") != NF || tmp.find("CHOICE") != NF || tmp.find("choice") != NF)
            section = false;

        if (!dialogscript || !section)
            continue;

        string str = "";
        string prefix = "";
        string suffix = "";
        int pos = 0;
        while (tmp[pos] != '-' && pos < tmp.length()) {
            prefix.pb(tmp[pos]);
            ++pos;
        }
        while (tmp[pos] != ':' && pos < tmp.length()) {
            prefix.pb(tmp[pos]);
            ++pos;
        }
        while (tmp[pos] != '\"' && pos < tmp.length()) {
            prefix.pb(tmp[pos]);
            ++pos;
        }
        ++pos;
        while (tmp[pos] != '\"' && pos < tmp.length()) {
            str.pb(tmp[pos]);
            ++pos;
        }
        while (pos < tmp.length()) {
            suffix.pb(tmp[pos]);
            ++pos;
        }
        if (!str.empty()) {
            //cout << "Original: " << tmp << el << "pref: [" << prefix << "] str: [" << str << "] suff: [" << suffix << "]\n";
            if (idByStr.count(str) > 0) {
                /// str
                /*cout << "Process id: " << idByStr[str] << el;
                if ( !hasSpeech.count(idByStr[str]) ) {
                    missedSpeech.pb(idByStr[str] + "|" + str);
                }*/
                adjustLines.pb({cntLine, {tmp, formatLine(prefix, suffix, idByStr[str], false)} });
                addToCustomCsv.pb(idByStr[str] + "|" + str);
            } else if (str.length() > 10) {
                string tryId = str.substr(0, 10);
                if (lineInfo.count(tryId) > 0) {
                    /*if ( !hasSpeech.count(tryId) ) {
                        missedSpeech.pb(tryId + "|" + lineInfo[tryId].Y);
                    }
                    cout << "Process id: " << tryId << el;*/

                    if (lineInfo[tryId].X != "-1") {
                        /// id|str
                        adjustLines.pb({cntLine, {tmp, formatLine(prefix, suffix, tryId, true)} });
                        addToCustomCsv.pb(tryId + "|" + lineInfo[tryId].Y);
                    }
                } else {
                    /// [dur]str
                    int pos = str.find("]");
                    if (pos != NF) {
                        ++pos;
                        str = str.substr(pos, str.length() - pos);
                        if (idByStr.count(str) > 0) {
                            /// str
                            /*if ( !hasSpeech.count(str) ) {
                                missedSpeech.pb(idByStr[str] + "|" + str);
                            }
                            cout << "Process id: " << idByStr[str] << el;*/

                            adjustLines.pb({cntLine, {tmp, formatLine(prefix, suffix, idByStr[str], false)} });
                            addToCustomCsv.pb(idByStr[str] + "|" + str);
                        }
                    }
                }
            }
        }
    }
	setConsoleColor(10);
    cout << "\nProcess " << p.filename().u8string() << "...\n";
	setConsoleColor(7);
    if (adjustLines.empty()) {
		setConsoleColor(6);
        cout << "   No dialog lines could be adjusted!\n";
		setConsoleColor(7);
        system("pause");
        return;
    } else {
		setConsoleColor(10);
        cout << "   These lines could be adjusted:\n";
		setConsoleColor(7);
    }
    upn(i, 0, (int)adjustLines.size() - 1) {
		setConsoleColor(6);
        cout << "      " << i + 1 << ". " << adjustLines[i].Y.X << "\n";
		setConsoleColor(11);
		cout << "   ->    " << adjustLines[i].Y.Y << el;
		setConsoleColor(7);
    }

    tmp = "";
    while (tmp.empty()) {
		setConsoleColor(10);
        cout << "\nAdjust dialog lines? (y/n): ";
        getline(cin, tmp);
    }
    setConsoleColor(7);
    if (tmp[0] != 'y')
        return;

    yml.clear();
    yml.seekg (0, ios::beg);
    int adjIdx = 0;


    fs::path newPath = scenesDir / (p.filename().u8string() + ".backup");
    fs::path oldPathNew = scenesDir / (p.filename().u8string() + ".new");
    ofstream out(oldPathNew.u8string());

    while (!yml.eof()) {
        getline(yml, tmp);
        ++cntLine2;
        if (adjIdx < (int) adjustLines.size() && adjustLines[adjIdx].X == cntLine2) {
            out << adjustLines[adjIdx].Y.Y << el;
            ++adjIdx;
        } else {
            out << tmp << el;
        }
    }
    yml.close();
    out.close();
    if (fs::exists(newPath)) {
        fs::remove(newPath);
    }
    fs::rename(p, newPath);
    fs::rename(oldPathNew, p);
	setConsoleColor(3);
    cout << "   Done! Backup old .yml as " << newPath.filename().u8string() << "\n";

    /*setConsoleColor(ccRED);
    if (!missedSpeech.empty())
        cout << "      MISSED SPEECH!\n";
    for (auto it : missedSpeech) {
        cout << it << el;
    }*/

	setConsoleColor(ccYELLOW);
	if (!addToCustomCsv.empty())
        cout << "      CHECK this in custom speech CSV file!\n";
    for (auto it : addToCustomCsv) {
        cout << it << el;
    }

    setConsoleColor(7);
}
void writeMissedSpeech() {
    for (auto i : lineInfo) {
        if (i.X.substr(0, 7) == modIdPrefix && i.X.substr(7, 3) > "200") {
            if (i.Y.X == "-1") {
                dbgout << i.X << "|" << i.Y.Y << el;
            }
        }
    }
}
int main()
{
    dbgout.open("_string_info.txt");
    modIdPrefix = "2114670";

    workDir = fs::current_path().u8string();
    speechDir = workDir / "speech" / "speech.en.wav";
    stringsDir = workDir / "strings";
    scenesDir = workDir / "definition.scenes";
    if (!fs::exists(speechDir)) {
		setConsoleColor(4);
        cout << "speech/speech.en.wav folder NOT FOUND!\nPut me in root of radish project folder." << el;
		setConsoleColor(7);
        system("pause");
        return 0;
    }
    if (!fs::exists(stringsDir / "all.en.strings.csv")) {
		setConsoleColor(4);
        cout << "strings/all.en.strings.csv NOT FOUND!\nRebuild project first." << el;
		setConsoleColor(7);
        system("pause");
        return 0;
    }
    if (!fs::exists(scenesDir)) {
		setConsoleColor(4);
        cout << "definition.scenes folder NOT FOUND!\nPut me in root of radish project folder." << el;
		setConsoleColor(7);
        system("pause");
        return 0;
    }

    for (const auto& dirEntry : fs::recursive_directory_iterator(speechDir)) {
        fs::path curPath = dirEntry.path();
        if (curPath.extension() == ".wav") {
            tryAddDuration(curPath);
        }
    }
    speechExtraDir = "D:/_w3.tools/_voicelines/EN.w3speech";
    stringsVanillaFile = "D:/_w3.tools/_voicelines/w3string.en.all.csv";

    tmp = "";
    while (tmp.empty()) {
		setConsoleColor(10);
        cout << "\nAdd vanilla lines? (y/n): ";
        getline(cin, tmp);
    }
    if (tmp == "y") {
        for (const auto& dirEntry : fs::recursive_directory_iterator(speechExtraDir)) {
            fs::path curPath = dirEntry.path();
            if (curPath.extension() == ".ogg") {
                tryAddDuration(curPath);
                //cout << "tryAdd: " << curPath.filename().u8string() << el;
            }
        }
        loadMainCsv(stringsVanillaFile);
    }
    tmp = "";
    while (tmp.empty()) {
		setConsoleColor(10);
        cout << "\nAdjust ids? (y/n): ";
        getline(cin, tmp);
    }
    adjustId = (tmp == "1" || tmp == "y");

    loadMainCsv(stringsDir / "all.en.strings.csv", adjustId);

    tmp = "";
    while (tmp.empty()) {
		setConsoleColor(10);
        cout << "\nWrite missed speech list? (y/n): ";
        getline(cin, tmp);
    }
    if (tmp == "y") {
        writeMissedSpeech();
    }
    //removeWithoutDuration();

    for (const auto& dirEntry : fs::recursive_directory_iterator(scenesDir)) {
        fs::path curPath = dirEntry.path();
        if (curPath.extension() == ".yml") {
            tryAdjustLines(curPath);
        }
    }
    setConsoleColor(10);
    cout << "ALL SCENES WERE PROCESSED! Have a nice day :)\n" << el;
    setConsoleColor(7);
    system("pause");
    return 0;
}
